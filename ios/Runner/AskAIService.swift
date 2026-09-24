import CryptoKit
import Flutter
import Foundation
import LocalQwen
import UIKit

private func askFailure(_ text: String) -> NSError {
  NSError(domain: "AskAI", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
}

/// URLSession writes large downloads to disk, never a multi-GB Data buffer.
private final class AskDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
  private let destination: URL
  private let progress: @Sendable (Double) -> Void
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Void, Error>?
  private var session: URLSession?
  private var task: URLSessionDownloadTask?
  private var cancelled = false
  private var moveError: Error?
  private var lastProgress = Date.distantPast
  private var lastDiagnosticProgress = -1
  init(destination: URL, progress: @escaping @Sendable (Double) -> Void) {
    self.destination = destination; self.progress = progress
  }
  func run(url: URL) async throws {
    try await withTaskCancellationHandler(operation: {
      try await withCheckedThrowingContinuation { (value: CheckedContinuation<Void, Error>) in
        lock.lock(); defer { lock.unlock() }
        if cancelled { value.resume(throwing: CancellationError()); return }
        continuation = value
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 7200
        config.waitsForConnectivity = false
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        task = session!.downloadTask(with: url)
        task!.resume()
      }
    }, onCancel: { self.cancel() })
  }
  private func cancel() {
    lock.lock(); defer { lock.unlock() }
    cancelled = true; task?.cancel()
  }
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    guard Date().timeIntervalSince(lastProgress) >= 0.15 || totalBytesWritten >= AskModelStore.size else { return }
    lastProgress = Date()
    let percent = Int(Double(totalBytesWritten) / Double(AskModelStore.size) * 100)
    if percent / 10 != lastDiagnosticProgress {
      lastDiagnosticProgress = percent / 10
      print("ASK_DOWNLOAD_DIAGNOSTIC progress=\(percent)% bytes=\(totalBytesWritten)")
    }
    progress(min(1, Double(totalBytesWritten) / Double(AskModelStore.size)))
  }
  func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL) {
    do {
      guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 else {
        throw askFailure("The model download was unavailable. Please retry.")
      }
      try FileManager.default.moveItem(at: location, to: destination)
    } catch { moveError = error }
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    let failure = (error ?? moveError) as NSError?
    print("ASK_DOWNLOAD_DIAGNOSTIC transfer_complete http=\((task.response as? HTTPURLResponse)?.statusCode ?? 0) error_domain=\(failure?.domain ?? "none") error_code=\(failure?.code ?? 0)")
    lock.lock()
    let value = continuation; continuation = nil
    lock.unlock()
    if let error = error ?? moveError { value?.resume(throwing: error) }
    else { value?.resume() }
    session.finishTasksAndInvalidate()
    self.session = nil; self.task = nil
  }
}

private actor AskModelStore {
  static let size: Int64 = 2740937888
  static let hash = "00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4"
  static let revision = "e87f176479d0855a907a41277aca2f8ee7a09523"
  private func root() throws -> URL {
    let support = try FileManager.default.url(for: .applicationSupportDirectory,
      in: .userDomainMask, appropriateFor: nil, create: true)
    var root = support.appendingPathComponent("ask_qwen35_4b_v1", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    var values = URLResourceValues(); values.isExcludedFromBackup = true
    try root.setResourceValues(values)
    return root
  }
  func status() throws -> Bool {
    let root = try root()
    return (try? String(contentsOf: root.appendingPathComponent("verified"), encoding: .utf8)) == Self.hash &&
      (try? root.appendingPathComponent("model.gguf").resourceValues(forKeys: [.fileSizeKey]).fileSize) == Int(Self.size)
  }
  private func verify(_ url: URL) throws {
    guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize) == Int(Self.size) else {
      throw askFailure("Incomplete model file. Delete it and download again.")
    }
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }
    var sha = SHA256()
    // Foundation read buffers may be autoreleased. Drain each chunk instead
    // of retaining buffers for the entire multi-GB synchronous actor operation.
    while try autoreleasepool(invoking: { () throws -> Bool in
      try Task.checkCancellation()
      guard let data = try file.read(upToCount: 1048576), !data.isEmpty else { return false }
      sha.update(data: data)
      return true
    }) {}
    guard sha.finalize().map({String(format:"%02x", $0)}).joined() == Self.hash else {
      throw askFailure("Model checksum mismatch. Delete it and download again.")
    }
  }
  func prepare(download: Bool, progress: @escaping @Sendable (Double) -> Void) async throws -> URL {
    let root = try root(), destination = root.appendingPathComponent("model.gguf")
    let pending = root.appendingPathComponent("completed.download")
    // Only this store owns these temporary files. Clean leftovers after process
    // termination; an active task is excluded by the bridge's single-work gate.
    for file in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
      where file.pathExtension == "partial" {
      try FileManager.default.removeItem(at: file)
    }
    if !FileManager.default.fileExists(atPath: destination.path) {
      guard download else { throw askFailure("Download the offline model first.") }
      if !FileManager.default.fileExists(atPath: pending.path) {
      let free = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
      print("ASK_DOWNLOAD_DIAGNOSTIC available_storage_bytes=\(free)")
      guard free > Self.size + 600_000_000 else { throw askFailure("Free at least 3.4 GB of storage before downloading.") }
      let url = URL(string: "https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/\(Self.revision)/Qwen3.5-4B-Q4_K_M.gguf")!
      // URLSession owns incomplete transfer data. A completed HTTP 200 file is
      // kept separately until verified, even if cancellation follows completion.
      try await AskDownload(destination: pending, progress: progress).run(url: url)
      } else {
        print("ASK_DOWNLOAD_DIAGNOSTIC reusing_completed_transfer")
      }
      try Task.checkCancellation()
      progress(1)
      do { try verify(pending) }
      catch {
        // Preserve completed bytes on cancellation. Invalid data must never be
        // promoted or reused indefinitely; a subsequent retry can download anew.
        if !Task.isCancelled { try? FileManager.default.removeItem(at: pending) }
        throw error
      }
      try Task.checkCancellation()
      try FileManager.default.moveItem(at: pending, to: destination)
    } else {
      // Validate again before inference, not just trusting an installed flag.
      try verify(destination)
    }
    try Data(Self.hash.utf8).write(to: root.appendingPathComponent("verified"), options: .atomic)
    print("ASK_DOWNLOAD_DIAGNOSTIC verified_model_ready")
    return destination
  }
  func remove() throws { try FileManager.default.removeItem(at: root()) }
}

@MainActor
final class AskAIService: NSObject, FlutterStreamHandler {
  private let store = AskModelStore()
  private let runtime = QwenRuntime()
  private var sink: FlutterEventSink?
  private var work: Task<Void, Never>?
  private var generation = 0
  private var downloading = false
  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterMethodChannel(name: "org.quranteacher/ask", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self else { result(nil); return }
        switch call.method {
        case "status": Task { result((try? await self.store.status()) ?? false) }
        case "download": self.start(evidence: nil, result: result)
        case "answer":
          guard let evidence = (call.arguments as? [String: Any])?["evidence"] as? String,
            evidence.utf8.count <= 24000 else {
            result(FlutterError(code: "invalid", message: "Question is too long.", details: nil)); return
          }
          self.start(evidence: evidence, result: result)
        case "cancel", "close": self.cancel(); result(nil)
        case "deleteModel":
          self.cancel()
          let previous = self.work
          Task {
            await previous?.value
            do { try await self.store.remove(); result(nil) }
            catch { result(FlutterError(code: "delete", message: error.localizedDescription, details: nil)) }
          }
        default: result(FlutterMethodNotImplemented)
        }
      }
    FlutterEventChannel(name: "org.quranteacher/ask/events", binaryMessenger: messenger).setStreamHandler(self)
    NotificationCenter.default.addObserver(self, selector: #selector(backgrounded),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(memoryWarning),
      name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    // Explicit developer launch only. Uses the real production downloader and
    // checksum checks, without a substitute transfer or fabricated results.
    if ProcessInfo.processInfo.arguments.contains("--diagnose-ask-download") {
      Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(8))
        self?.start(evidence: nil) { result in
          if let error = result as? FlutterError {
            print("ASK_DOWNLOAD_DIAGNOSTIC result=\(error.code) message=\(error.message ?? "")")
          } else { print("ASK_DOWNLOAD_DIAGNOSTIC result=success") }
        }
      }
    }
    if ProcessInfo.processInfo.arguments.contains("--diagnose-ask-answer") {
      Task { @MainActor [weak self] in
        try? await Task.sleep(for: .seconds(8))
        // Fixed public test evidence only; never log ordinary user questions.
        let evidence = #"{"question":"What does this verse say about Allah?","passages":[{"source":1,"reference":"Qur’an 112:1","english":"Say: “He is Allah, the One[1];","provenance":"Rowwad Translation Center · QuranEnc.com · v1.0.19"}]}"#
        self?.start(evidence: evidence) { result in
          if let error = result as? FlutterError {
            print("ASK_ANSWER_TEST error=\(error.code) message=\(error.message ?? "")")
          } else if let response = result as? [String: Any] {
            print("ASK_ANSWER_TEST seconds=\(response["seconds"] ?? "unknown") output=\(response["text"] ?? "")")
          }
        }
      }
    }
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink = events; return nil }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { cancel(); sink = nil; return nil }
  @objc private func backgrounded() { cancel(reason: "app_backgrounded") }
  @objc private func memoryWarning() { cancel(reason: "ios_memory_warning") }
  private func cancel(reason: String = "screen_or_user_cancel") {
    if downloading { print("ASK_DOWNLOAD_DIAGNOSTIC cancel_reason=\(reason)") }
    generation += 1; work?.cancel()
    sink?(["state":"cancelled"])
  }
  private func start(evidence: String?, result: @escaping FlutterResult) {
    guard work == nil else {
      result(FlutterError(code: "busy", message: "The previous task is finishing. Please retry shortly.", details: nil)); return
    }
    generation += 1; let token = generation
    downloading = evidence == nil
    if downloading { print("ASK_DOWNLOAD_DIAGNOSTIC started") }
    let state = evidence == nil ? "downloading" : "loading"
    sink?(["state": state])
    work = Task {
      defer { work = nil; downloading = false }
      do {
        let file = try await store.prepare(download: evidence == nil) { [weak self] progress in
          Task { @MainActor in
            guard let self, self.generation == token else { return }
            self.sink?(["state": "downloading", "progress": progress])
          }
        }
        try Task.checkCancellation()
        if let evidence {
          sink?(["state":"generating"])
          let start = Date()
          let answer = try await runtime.answer(modelPath: file.path, evidence: evidence)
          try Task.checkCancellation()
          guard token == generation else { throw CancellationError() }
          result(["text":answer, "seconds": Date().timeIntervalSince(start)])
        } else { result(nil) }
      } catch {
        result(FlutterError(code: Task.isCancelled ? "cancelled" : "failed",
          message: Task.isCancelled ? "Stopped." : error.localizedDescription, details: nil))
      }
    }
  }
}
