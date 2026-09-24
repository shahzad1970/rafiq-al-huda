import AVFoundation
import Flutter
import UIKit

/// Ephemeral native capture. No acoustic model or substitute feature extractor.
final class QuranAudioService: NSObject, FlutterStreamHandler {
  /// Native-only, ephemeral handoff to the on-device feature extractor.
  /// The callback receives the same 16 kHz mono PCM16LE bytes sent to Flutter.
  var onPCM16LE: ((Data) -> Void)?
  private let engine = AVAudioEngine()
  private let queue = DispatchQueue(label: "org.quranteacher.audio", qos: .userInitiated)
  private let capacity = DispatchSemaphore(value: 8)
  private let lock = NSLock()
  private var generation = 0
  private var running = false
  private var tapInstalled = false
  private var previousIdleTimerDisabled: Bool?
  private var converter: AVAudioConverter?
  private var sink: FlutterEventSink?
  private var sequence = 0
  private var startSample = 0
  private var observers: [NSObjectProtocol] = []

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterMethodChannel(name: "org.quranteacher/audio", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self else { result(FlutterError(code: "disposed", message: nil, details: nil)); return }
        switch call.method {
        case "start": self.requestStart(result)
        case "isSubscribed": result(self.sink != nil)
        case "stop": self.stop(); result(nil)
        case "calibrationDirectory": self.calibrationDirectory(result)
        case "excludeFromBackup": self.excludeFromBackup(call, result: result)
        default: result(FlutterMethodNotImplemented)
        }
      }
    FlutterEventChannel(name: "org.quranteacher/audio/events", binaryMessenger: messenger).setStreamHandler(self)
    observers.append(NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      guard let self, self.isActive(),
        let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
        AVAudioSession.InterruptionType(rawValue: rawType) == .began else { return }
      self.fail("capture_interrupted", "Recording was interrupted by another audio session. Tap the microphone to try again.")
    })
    observers.append(NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] notification in
      guard let self, self.isActive(),
        let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
        let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }

      // setCategory/setActive can emit categoryChange or routeConfigurationChange
      // while a healthy capture is starting. Those are informational, not failures.
      switch reason {
      case .oldDeviceUnavailable, .noSuitableRouteForCategory:
        self.fail("audio_input_unavailable", "The microphone input changed or became unavailable. Tap the microphone to try again.")
      default:
        break
      }
    })
    observers.append(NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      guard let self, self.isActive() else { return }
      self.fail("capture_paused", "Recording stopped when the app moved to the background.")
    })
  }
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? { sink = events; return nil }
  func onCancel(withArguments arguments: Any?) -> FlutterError? { stop(); sink = nil; return nil }
  private func isActive(_ expected: Int? = nil) -> Bool {
    lock.lock(); defer { lock.unlock() }
    return running && (expected == nil || expected == generation)
  }
  private func requestStart(_ result: @escaping FlutterResult) {
    guard sink != nil else { result(FlutterError(code: "no_audio_listener", message: "Subscribe to audio first", details: nil)); return }
    guard !isActive() else { result(nil); return }
    lock.lock(); generation += 1; let token = generation; lock.unlock()
    AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
      DispatchQueue.main.async {
        guard let self else { return }
        self.lock.lock(); let current = self.generation; self.lock.unlock()
        guard current == token else { result(FlutterError(code: "cancelled", message: "Start cancelled", details: nil)); return }
        guard granted else { result(FlutterError(code: "microphone_denied", message: "Allow microphone in Settings", details: nil)); return }
        do { try self.start(token: token); result(nil) }
        catch { self.stop(); result(FlutterError(code: "audio_start_failed", message: error.localizedDescription, details: nil)) }
      }
    }
  }
  private func start(token: Int) throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .measurement)
    try session.setActive(true)
    let input = engine.inputNode
    let source = input.outputFormat(forBus: 0)
    guard source.sampleRate > 0, source.channelCount > 0,
      let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
      let converter = AVAudioConverter(from: source, to: target) else {
      throw NSError(domain: "QuranAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported microphone format"])
    }
    queue.sync { self.converter = converter; sequence = 0; startSample = 0 }
    lock.lock(); running = true; lock.unlock()
    input.installTap(onBus: 0, bufferSize: 2048, format: source) { [weak self] buffer, _ in
      guard let self, self.isActive(token) else { return }
      guard self.capacity.wait(timeout: .now()) == .success else {
        DispatchQueue.main.async { if self.isActive(token) { self.fail("audio_overrun", "Audio queue overflow; restart capture") } }; return
      }
      guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { self.capacity.signal(); return }
      copy.frameLength = buffer.frameLength
      let src = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
      let dst = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
      for i in 0..<src.count {
        if let from = src[i].mData, let to = dst[i].mData { memcpy(to, from, Int(src[i].mDataByteSize)) }
      }
      self.queue.async { self.process(copy, target: target, token: token) }
    }
    tapInstalled = true
    engine.prepare(); try engine.start()
    // Owned by actual capture, not a Flutter toggle. All capture stop/error
    // paths restore auto-lock, including interruption and backgrounding.
    previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
    UIApplication.shared.isIdleTimerDisabled = true
  }
  private func process(_ input: AVAudioPCMBuffer, target: AVAudioFormat, token: Int) {
    guard isActive(token), let converter else { capacity.signal(); return }
    let count = AVAudioFrameCount(ceil(Double(input.frameLength) * 16000 / input.format.sampleRate) + 64)
    guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: count) else { capacity.signal(); return }
    var supplied = false
    var error: NSError?
    let status = converter.convert(to: output, error: &error) { _, inputStatus in
      if supplied { inputStatus.pointee = .noDataNow; return nil }
      supplied = true; inputStatus.pointee = .haveData; return input
    }
    guard status != .error, error == nil, let channel = output.floatChannelData?[0] else {
      capacity.signal()
      let message = error?.localizedDescription ?? "PCM conversion failed"
      DispatchQueue.main.async { if self.isActive(token) { self.fail("audio_conversion_failed", message) } }; return
    }
    guard output.frameLength > 0 else { capacity.signal(); return }
    var pcm = Data(capacity: Int(output.frameLength) * 2)
    for i in 0..<Int(output.frameLength) {
      let value = max(-1.0, min(1.0, channel[i]))
      var sample = Int16(max(-32768, min(32767, Int(value * 32768)))).littleEndian
      withUnsafeBytes(of: &sample) { pcm.append(contentsOf: $0) }
    }
    let event: [String: Any] = ["pcm": FlutterStandardTypedData(bytes: pcm), "sampleRate": 16000,
      "inputSampleRate": input.format.sampleRate, "channels": 1, "encoding": "pcm16le",
      "sequence": sequence, "startSample": startSample]
    sequence += 1; startSample += Int(output.frameLength)
    onPCM16LE?(pcm)
    DispatchQueue.main.async { if self.isActive(token) { self.sink?(event) }; self.capacity.signal() }
  }
  private func fail(_ code: String, _ message: String) { stop(); sink?(FlutterError(code: code, message: message, details: nil)) }
  private func calibrationDirectory(_ result: @escaping FlutterResult) {
    do {
      let support = try FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      var directory = support.appendingPathComponent("calibration_recordings", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try directory.setResourceValues(values)
      result(directory.path)
    } catch {
      result(FlutterError(code: "calibration_directory_failed", message: error.localizedDescription, details: nil))
    }
  }
  private func excludeFromBackup(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
      let path = arguments["path"] as? String else {
      result(FlutterError(code: "invalid_path", message: "A local directory path is required.", details: nil)); return
    }
    let standardized = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL.path + "/"
    guard standardized.path.hasPrefix(home) else {
      result(FlutterError(code: "invalid_path", message: "Directory must be inside the app container.", details: nil)); return
    }
    do {
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var mutableURL = standardized
      try mutableURL.setResourceValues(values)
      result(nil)
    } catch {
      result(FlutterError(code: "backup_exclusion_failed", message: error.localizedDescription, details: nil))
    }
  }
  private func stop() {
    if let previous = previousIdleTimerDisabled {
      UIApplication.shared.isIdleTimerDisabled = previous
      previousIdleTimerDisabled = nil
    }
    lock.lock(); running = false; generation += 1; lock.unlock()
    engine.stop()
    if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
    queue.sync { converter = nil }
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
  deinit {
    if let previous = previousIdleTimerDisabled {
      DispatchQueue.main.async { UIApplication.shared.isIdleTimerDisabled = previous }
    }
    observers.forEach { NotificationCenter.default.removeObserver($0) }
  }
}

/// Local bundled AbdulBaset Mujawwad playback with optional word-range stops.
final class QuranPlaybackService: NSObject, FlutterStreamHandler, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {
  private let synthesizer = AVSpeechSynthesizer()
  private var currentSpeech: AVSpeechUtterance?
  private let registrar: FlutterPluginRegistrar
  private var player: AVAudioPlayer?
  private var sink: FlutterEventSink?
  private var stopWorkItem: DispatchWorkItem?
  private var progressTimer: Timer?
  private var generation = 0

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
    synthesizer.delegate = self
    FlutterMethodChannel(name: "org.quranteacher/playback", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "disposed", message: nil, details: nil)); return
        }
        switch call.method {
        case "play": self.play(call, result: result)
        case "speakArabic": self.speakArabic(call, result: result)
        case "cache": self.cache(call, result: result)
        case "clearCache": self.clearCache(result)
        case "stop": self.stop(sendEvent: true); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    FlutterEventChannel(name: "org.quranteacher/playback/events", binaryMessenger: registrar.messenger())
      .setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    stop(sendEvent: false)
    return nil
  }

  private func play(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "invalid_audio", message: "Audio details are required.", details: nil)); return
    }
    stop(sendEvent: false)
    generation += 1
    let token = generation
    Task {
      do {
        let url = try await self.localAudioURL(arguments)
        await MainActor.run {
          guard self.generation == token else {
            result(FlutterError(code: "cancelled", message: "Playback was cancelled.", details: nil)); return
          }
          self.startPlayer(url: url, arguments: arguments, result: result)
        }
      } catch {
        await MainActor.run {
          guard self.generation == token else {
            result(FlutterError(code: "cancelled", message: "Playback was cancelled.", details: nil)); return
          }
          self.sink?(["state": "error", "message": error.localizedDescription])
          result(FlutterError(code: "audio_download_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func speakArabic(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    stop(sendEvent: false)
    guard let args = call.arguments as? [String: Any], let text = args["text"] as? String,
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 4000 else {
      result(FlutterError(code: "invalid_speech", message: "An Arabic phrase is required.", details: nil)); return
    }
    let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ar") }
      .sorted { $0.quality.rawValue > $1.quality.rawValue }
    guard let voice = voices.first else {
      result(FlutterError(code: "arabic_voice_missing", message: "Download an Arabic voice in iPhone Settings → Accessibility → Spoken Content → Voices.", details: nil)); return
    }
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
      try AVAudioSession.sharedInstance().setActive(true)
      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = voice
      utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
      currentSpeech = utterance
      synthesizer.speak(utterance)
      sink?(["state": "playing"])
      result(nil)
    } catch {
      result(FlutterError(code: "speech_failed", message: error.localizedDescription, details: nil))
    }
  }

  func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    guard currentSpeech === utterance else { return }
    currentSpeech = nil
    sink?(["state": "completed"])
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func startPlayer(url: URL, arguments: [String: Any], result: @escaping FlutterResult) {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .spokenAudio)
      try session.setActive(true)
      let next = try AVAudioPlayer(contentsOf: url)
      next.delegate = self
      next.prepareToPlay()
      let requestedRate = (arguments["rate"] as? NSNumber)?.floatValue ?? 1
      let playbackRate = min(2, max(0.5, requestedRate))
      next.enableRate = true
      next.rate = playbackRate
      let start = (arguments["startMilliseconds"] as? NSNumber)?.doubleValue ?? 0
      let end = (arguments["endMilliseconds"] as? NSNumber)?.doubleValue
      next.currentTime = max(0, start / 1000)
      guard next.play() else {
        throw NSError(domain: "QuranPlayback", code: 1, userInfo: [NSLocalizedDescriptionKey: "The recitation could not start."])
      }
      player = next
      sink?(["state": "playing"])
      progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self, weak next] _ in
        guard let self, let next, self.player === next, next.isPlaying else { return }
        self.sink?([
          "state": "progress",
          "positionMilliseconds": Int((next.currentTime * 1000).rounded())
        ])
      }
      if let end, end > start {
        let work = DispatchWorkItem { [weak self, weak next] in
          guard let self, self.player === next else { return }
          self.stopWorkItem = nil
          self.progressTimer?.invalidate()
          self.progressTimer = nil
          next?.stop()
          self.player = nil
          self.sink?(["state": "completed"])
          try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        stopWorkItem = work
        let wallDuration = (end - start) / 1000 / Double(playbackRate)
        DispatchQueue.main.asyncAfter(deadline: .now() + wallDuration, execute: work)
      }
      result(nil)
    } catch {
      sink?(["state": "error", "message": error.localizedDescription])
      result(FlutterError(code: "playback_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func localAudioURL(_ arguments: [String: Any]) async throws -> URL {
    if let asset = arguments["asset"] as? String {
      let assetKey = registrar.lookupKey(forAsset: asset)
      if let path = Bundle.main.path(forResource: assetKey, ofType: nil) {
        return URL(fileURLWithPath: path)
      }
    }
    guard let remoteValue = arguments["remoteUrl"] as? String,
      let remoteURL = URL(string: remoteValue),
      remoteURL.scheme == "https",
      remoteURL.host == "verses.quran.foundation",
      let cacheKey = arguments["cacheKey"] as? String,
      cacheKey.range(of: #"^\d{6}\.mp3$"#, options: .regularExpression) != nil else {
      throw NSError(domain: "QuranPlayback", code: 2, userInfo: [NSLocalizedDescriptionKey: "The recitation source is invalid."])
    }
    let destination = try cacheDirectory().appendingPathComponent(cacheKey)
    if FileManager.default.fileExists(atPath: destination.path) { return destination }
    let (temporary, response) = try await URLSession.shared.download(from: remoteURL)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw NSError(domain: "QuranPlayback", code: 3, userInfo: [NSLocalizedDescriptionKey: "The recitation could not be downloaded."])
    }
    try? FileManager.default.removeItem(at: destination)
    try FileManager.default.moveItem(at: temporary, to: destination)
    return destination
  }

  private func cacheDirectory() throws -> URL {
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    var directory = support.appendingPathComponent("abdulbaset_mujawwad", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try directory.setResourceValues(values)
    return directory
  }

  private func cache(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
      let items = arguments["items"] as? [[String: Any]] else {
      result(FlutterError(code: "invalid_audio", message: "Audio download list is required.", details: nil)); return
    }
    Task {
      do {
        for (index, item) in items.enumerated() {
          _ = try await self.localAudioURL(item)
          await MainActor.run {
            self.sink?(["state": "downloadProgress", "completed": index + 1, "total": items.count])
          }
        }
        await MainActor.run {
          self.sink?(["state": "downloadCompleted", "completed": items.count, "total": items.count])
          result(nil)
        }
      } catch {
        await MainActor.run {
          result(FlutterError(code: "audio_download_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func clearCache(_ result: @escaping FlutterResult) {
    stop(sendEvent: true)
    do {
      let directory = try cacheDirectory()
      for item in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
        try FileManager.default.removeItem(at: item)
      }
      result(nil)
    } catch {
      result(FlutterError(code: "audio_cache_delete_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func stop(sendEvent: Bool) {
    generation += 1
    let wasPlaying = player?.isPlaying == true || currentSpeech != nil
    currentSpeech = nil
    synthesizer.stopSpeaking(at: .immediate)
    stopWorkItem?.cancel()
    stopWorkItem = nil
    progressTimer?.invalidate()
    progressTimer = nil
    player?.stop()
    player = nil
    if sendEvent && wasPlaying { sink?(["state": "stopped"]) }
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    guard self.player === player else { return }
    stopWorkItem?.cancel()
    stopWorkItem = nil
    progressTimer?.invalidate()
    progressTimer = nil
    self.player = nil
    sink?(["state": flag ? "completed" : "error", "message": flag ? "" : "Playback ended unexpectedly."])
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
