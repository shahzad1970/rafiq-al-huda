import CoreML
import Flutter
import Foundation

/// Quran-Lab v3.1 streaming Core ML runner. It performs acoustic inference and
/// authoritative token decoding only: no alignment, correction, scoring, or
/// tajwid claims are made here.
final class QuranCoreMLService: NSObject, FlutterStreamHandler {
  private struct TokenRun {
    let token: Int
    let startFrame: Int
    var endFrame: Int
    var probabilitySum: Double
    var frameCount: Int
    var peakProbability: Double
    var peakMargin: Double
  }
  private static let channelName = "org.quranteacher/speech/coreml"
  private static let eventChannelName = "org.quranteacher/speech/coreml/events"
  private static let modelBaseName = "zipformer_p_arabic_v3.1.float8"
  private static let inputFrames = 61
  private static let advanceFrames = 48
  private static let featureDimension = 80
  private static let blankID = 250

  private let queue = DispatchQueue(label: "org.quranteacher.coreml", qos: .userInitiated)
  private let pcmLock = NSLock()
  private var queuedPCMBytes = 0
  private var pcmOverrun = false
  private var eventSink: FlutterEventSink?
  private var front: MLModel?
  private var back: MLModel?
  private var tokens: [Int: String] = [:]
  private var frontStates: [String: MLMultiArray] = [:]
  private var backStates: [String: MLMultiArray] = [:]
  private var processedLens: MLMultiArray?
  private var extractor = QuranFbankExtractor()
  private var nextFeatureFrame = 0
  private var featureBuffer: [[Float]] = []
  private var recognizing = false
  private var tokenRun: TokenRun?
  private var outputFrame = 0
  private var sequencePosition = 0
  private var lastChunkProcessingMillis = 0.0
  private var status: [String: Any] = ["state": "notInitialized"]

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "disposed", message: nil, details: nil)); return
        }
        switch call.method {
        case "initialize": self.initializeModel(result)
        case "status": result(self.status)
        case "start": self.startRecognition(result)
        case "stop": self.stopRecognition(result)
        case "reset": self.resetRecognition(); result(nil)
        case "dispose": self.dispose(); result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
    FlutterEventChannel(name: Self.eventChannelName, binaryMessenger: messenger)
      .setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events; return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil; return nil
  }

  /// Native microphone handoff. PCM is discarded as soon as feature extraction
  /// completes; no recording is persisted.
  func acceptPCM16LE(_ pcm: Data) {
    // At most two seconds of PCM16 mono at 16 kHz, including in-flight work.
    // Fail explicitly on overload rather than dropping samples or growing RAM.
    pcmLock.lock()
    if pcmOverrun { pcmLock.unlock(); return }
    if queuedPCMBytes + pcm.count > 64_000 {
      pcmOverrun = true
      pcmLock.unlock()
      queue.async { [weak self] in
        guard let self else { return }
        self.failRecognition(self.contractError("Recognition could not keep up with microphone audio. Restart listening."))
      }
      return
    }
    queuedPCMBytes += pcm.count
    pcmLock.unlock()
    queue.async { [weak self] in
      guard let self else { return }
      defer {
        self.pcmLock.lock()
        self.queuedPCMBytes -= pcm.count
        self.pcmLock.unlock()
      }
      guard self.recognizing else { return }
      do {
        try self.extractFeatures(pcm)
        try self.processReadyChunks()
      } catch { self.failRecognition(error) }
    }
  }

  private func initializeModel(_ result: @escaping FlutterResult) {
    if front != nil, back != nil { result(status); return }
    queue.async { [weak self] in
      guard let self else { return }
      do {
        let loaded = try self.loadAndValidate()
        self.front = loaded.front; self.back = loaded.back; self.tokens = loaded.tokens
        try self.resetStateArrays()
        self.status = loaded.status
        DispatchQueue.main.async { result(loaded.status) }
      } catch {
        self.status = ["state": "error", "message": error.localizedDescription]
        DispatchQueue.main.async {
          result(FlutterError(code: "coreml_initialization_failed",
            message: error.localizedDescription, details: self.status))
        }
      }
    }
  }

  private func startRecognition(_ result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self else { return }
      guard self.front != nil, self.back != nil else {
        DispatchQueue.main.async {
          result(FlutterError(code: "coreml_not_initialized",
            message: "Initialize the Quran-Lab model before listening.", details: self.status))
        }
        return
      }
      do {
        try self.resetStreamingState(); self.recognizing = true
        DispatchQueue.main.async { result(nil) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "coreml_start_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func stopRecognition(_ result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      self.recognizing = false
      self.extractor.finishInput()
      do {
        try self.collectReadyFrames()
        try self.processReadyChunks()
        try self.flushFinalPartialChunk()
        self.flushTokenRun()
        self.featureBuffer.removeAll(keepingCapacity: false)
        // Token events and this completion are enqueued on the same serial main
        // queue, so Flutter receives the final flush before stop completes.
        DispatchQueue.main.async { result(nil) }
      }
      catch {
        self.featureBuffer.removeAll(keepingCapacity: false)
        self.failRecognition(error)
        DispatchQueue.main.async {
          result(FlutterError(code: "coreml_stop_failed",
            message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func resetRecognition() {
    queue.async { [weak self] in
      guard let self else { return }
      do { try self.resetStreamingState() } catch { self.failRecognition(error) }
    }
  }

  private func dispose() {
    queue.async { [weak self] in
      guard let self else { return }
      self.recognizing = false; self.front = nil; self.back = nil
      self.tokens.removeAll(); self.frontStates.removeAll(); self.backStates.removeAll()
      self.processedLens = nil; self.featureBuffer.removeAll(); self.extractor.reset()
    }
  }

  private func resetStreamingState() throws {
    pcmLock.lock(); pcmOverrun = false; pcmLock.unlock()
    recognizing = false; extractor.reset(); nextFeatureFrame = 0
    featureBuffer.removeAll(keepingCapacity: true)
    tokenRun = nil; outputFrame = 0; sequencePosition = 0
    lastChunkProcessingMillis = 0
    try resetStateArrays()
  }

  private func extractFeatures(_ pcm: Data) throws {
    try extractor.acceptPCM16LEData(pcm)
    try collectReadyFrames()
  }

  private func collectReadyFrames() throws {
    while nextFeatureFrame < extractor.numberOfFramesReady {
      let data = try extractor.frameFloat32Data(at: nextFeatureFrame)
      guard data.count == Self.featureDimension * MemoryLayout<Float>.size else {
        throw contractError("Fbank frame had an invalid byte count.")
      }
      featureBuffer.append(data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) })
      nextFeatureFrame += 1
    }
  }

  private func processReadyChunks() throws {
    while featureBuffer.count >= Self.inputFrames {
      try infer(Array(featureBuffer.prefix(Self.inputFrames)))
      featureBuffer.removeFirst(Self.advanceFrames)
    }
  }

  private func flushFinalPartialChunk() throws {
    // A 61-frame input advances 48 frames and retains 13 frames of right
    // context. Only pad when real frames remain beyond that retained context.
    guard featureBuffer.count > Self.inputFrames - Self.advanceFrames else { return }
    let zeroFrame = [Float](repeating: 0, count: Self.featureDimension)
    while featureBuffer.count < Self.inputFrames { featureBuffer.append(zeroFrame) }
    try infer(Array(featureBuffer.prefix(Self.inputFrames)))
    featureBuffer.removeAll(keepingCapacity: false)
  }

  private func infer(_ features: [[Float]]) throws {
    let chunkStart = CFAbsoluteTimeGetCurrent()
    guard let front, let back, let processedLens else {
      throw contractError("Core ML state is unavailable.")
    }
    let x = try MLMultiArray(shape: [1, NSNumber(value: Self.inputFrames),
      NSNumber(value: Self.featureDimension)], dataType: .float16)
    for frame in 0..<Self.inputFrames {
      for bin in 0..<Self.featureDimension {
        x[[0, NSNumber(value: frame), NSNumber(value: bin)]] = NSNumber(value: features[frame][bin])
      }
    }
    var frontInput: [String: MLFeatureValue] = [
      "x": MLFeatureValue(multiArray: x),
      "processed_lens": MLFeatureValue(multiArray: processedLens),
    ]
    for (name, value) in frontStates { frontInput[name] = MLFeatureValue(multiArray: value) }
    let frontOutput = try front.prediction(from: MLDictionaryFeatureProvider(dictionary: frontInput))
    guard let intermediate = frontOutput.featureValue(for: "input_tensor_1439_cast_fp16")?.multiArrayValue else {
      throw contractError("Core ML front output tensor is missing.")
    }
    var backInput: [String: MLFeatureValue] = [
      "input_tensor_1439_cast_fp16": MLFeatureValue(multiArray: intermediate),
      "processed_lens": MLFeatureValue(multiArray: processedLens),
    ]
    for (name, value) in backStates { backInput[name] = MLFeatureValue(multiArray: value) }
    let backOutput = try back.prediction(from: MLDictionaryFeatureProvider(dictionary: backInput))
    guard let logits = backOutput.featureValue(for: "log_probs")?.multiArrayValue,
          let newProcessed = frontOutput.featureValue(for: "new_processed_lens")?.multiArrayValue else {
      throw contractError("Core ML output tensor or processed length is missing.")
    }
    for name in Array(frontStates.keys) {
      guard let value = frontOutput.featureValue(for: "new_\(name)")?.multiArrayValue else {
        throw contractError("Core ML front state new_\(name) is missing.")
      }
      frontStates[name] = value
    }
    for name in Array(backStates.keys) {
      guard let value = backOutput.featureValue(for: "new_\(name)")?.multiArrayValue else {
        throw contractError("Core ML back state new_\(name) is missing.")
      }
      backStates[name] = value
    }
    self.processedLens = newProcessed
    lastChunkProcessingMillis = (CFAbsoluteTimeGetCurrent() - chunkStart) * 1_000
    try decode(logits)
  }

  private func decode(_ logProbabilities: MLMultiArray) throws {
    let shape = logProbabilities.shape.map(\.intValue)
    guard shape == [1, 12, 251] else { throw contractError("Unexpected log_probs shape \(shape).") }
    for frame in 0..<12 {
      var bestID = 0
      var bestLogProbability = -Float.infinity
      var secondLogProbability = -Float.infinity
      for token in 0..<251 {
        let value = logProbabilities[[0, NSNumber(value: frame), NSNumber(value: token)]].floatValue
        if value > bestLogProbability {
          secondLogProbability = bestLogProbability
          bestLogProbability = value
          bestID = token
        } else if value > secondLogProbability {
          secondLogProbability = value
        }
      }
      let probability = Double(exp(bestLogProbability))
      let runnerUp = Double(exp(secondLogProbability))
      let margin = probability - runnerUp
      if tokenRun?.token != bestID {
        flushTokenRun()
        if bestID != Self.blankID {
          tokenRun = TokenRun(token: bestID, startFrame: outputFrame,
            endFrame: outputFrame, probabilitySum: probability, frameCount: 1,
            peakProbability: probability, peakMargin: margin)
        }
      } else if bestID != Self.blankID {
        tokenRun?.endFrame = outputFrame
        tokenRun?.probabilitySum += probability
        tokenRun?.frameCount += 1
        if probability > (tokenRun?.peakProbability ?? 0) {
          tokenRun?.peakProbability = probability
          tokenRun?.peakMargin = margin
        }
      }
      outputFrame += 1
    }
  }

  private func flushTokenRun() {
    guard let run = tokenRun else { return }
    tokenRun = nil
    guard let phoneme = tokens[run.token] else {
      failRecognition(contractError("Decoded token \(run.token) is absent from tokens.txt."))
      return
    }
    let event: [String: Any] = [
      "token": run.token, "decodedPhoneme": phoneme,
      "confidence": run.probabilitySum / Double(run.frameCount),
      "confidencePeak": run.peakProbability, "marginPeak": run.peakMargin,
      "startMicros": run.startFrame * 40_000,
      "endMicros": (run.endFrame + 1) * 40_000,
      "frames": run.frameCount, "sequencePosition": sequencePosition,
      "chunkProcessingMillis": lastChunkProcessingMillis,
      "realTimeFactor": lastChunkProcessingMillis / 480.0,
      "finalized": true, "source": "quran_lab_coreml_v3_1",
    ]
    sequencePosition += 1
    DispatchQueue.main.async { [weak self] in self?.eventSink?(event) }
  }

  private func resetStateArrays() throws {
    guard let front, let back else { return }
    frontStates = try makeZeroStates(for: front); backStates = try makeZeroStates(for: back)
    processedLens = try MLMultiArray(shape: [1], dataType: .int32); processedLens?[0] = 0
  }

  private func makeZeroStates(for model: MLModel) throws -> [String: MLMultiArray] {
    var states: [String: MLMultiArray] = [:]
    for (name, description) in model.modelDescription.inputDescriptionsByName where name.hasPrefix("sg_") {
      guard let constraint = description.multiArrayConstraint else {
        throw contractError("State \(name) has no multi-array constraint.")
      }
      let state = try MLMultiArray(shape: constraint.shape, dataType: constraint.dataType)
      // Core ML does not promise initialized MLMultiArray storage. Zipformer
      // cache tensors must be exactly zero on the first streaming call.
      for index in 0..<state.count { state[index] = 0 }
      states[name] = state
    }
    return states
  }

  private func failRecognition(_ error: Error) {
    recognizing = false
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(FlutterError(code: "coreml_stream_failed",
        message: error.localizedDescription, details: nil))
    }
  }

  private func loadAndValidate() throws -> (front: MLModel, back: MLModel,
    tokens: [Int: String], status: [String: Any]) {
    guard #available(iOS 18.0, *) else {
      throw contractError("Quran-Lab Float8 Core ML requires iOS 18 or later.")
    }
    guard let modelURL = Bundle.main.url(forResource: Self.modelBaseName, withExtension: "mlmodelc")
      ?? Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil)?
        .first(where: { $0.lastPathComponent.hasPrefix(Self.modelBaseName) }) else {
      throw contractError("Bundled Quran-Lab Core ML model was not found.")
    }
    let frontConfiguration = MLModelConfiguration()
    frontConfiguration.computeUnits = .cpuAndNeuralEngine; frontConfiguration.functionName = "front"
    let loadedFront = try MLModel(contentsOf: modelURL, configuration: frontConfiguration)
    let backConfiguration = MLModelConfiguration()
    backConfiguration.computeUnits = .cpuAndNeuralEngine; backConfiguration.functionName = "back"
    let loadedBack = try MLModel(contentsOf: modelURL, configuration: backConfiguration)

    let metadata = loadedFront.modelDescription.metadata[.creatorDefinedKey] as? [String: String] ?? [:]
    try require(metadata["model_type"] == "zipformer2", "model_type must be zipformer2")
    try require(metadata["version"] == "3.1", "model version must be 3.1")
    try require(metadata["feature_type"] == "kaldi_fbank_povey", "feature type mismatch")
    try require(metadata["sample_rate"] == "16000", "sample rate mismatch")
    try require(metadata["feature_dim"] == "80", "feature dimension mismatch")
    try require(metadata["T"] == "61", "front chunk length mismatch")
    try require(metadata["decode_chunk_len"] == "48", "decode hop mismatch")
    try require(metadata["blank_id"] == "250", "CTC blank mismatch")
    try require(metadata["call_order"] == "front,back", "Core ML call order mismatch")
    try requireShape(loadedFront, feature: "x", expected: [1, 61, 80], output: false)
    try requireShape(loadedFront, feature: "processed_lens", expected: [1], output: false)
    try requireShape(loadedFront, feature: "input_tensor_1439_cast_fp16",
      expected: [24, 1, 384], output: true)
    try requireShape(loadedBack, feature: "log_probs", expected: [1, 12, 251], output: true)
    let tokenTable = try validateTokens()
    return (loadedFront, loadedBack, tokenTable, [
      "state": "readyForDeviceValidation", "model": Self.modelBaseName,
      "version": metadata["version"] ?? "", "precision": metadata["precision"] ?? "",
      "featureType": metadata["feature_type"] ?? "", "sampleRate": 16_000,
      "featureDimension": 80, "inputFrames": Self.inputFrames,
      "decodeChunkFrames": Self.advanceFrames, "blankId": Self.blankID,
      "tokenCount": tokenTable.count, "computeUnits": "cpuAndNeuralEngine",
      "recognitionEnabled": true, "validationStatus": "unverified_on_physical_device",
    ])
  }

  private func validateTokens() throws -> [Int: String] {
    guard let url = Bundle.main.url(forResource: "tokens", withExtension: "txt") else {
      throw contractError("Bundled tokens.txt was not found.")
    }
    let lines = try String(contentsOf: url, encoding: .utf8).split(whereSeparator: \.isNewline)
    var result: [Int: String] = [:]
    for line in lines {
      let fields = line.split(separator: " ", omittingEmptySubsequences: true)
      guard fields.count >= 2, let id = Int(fields.last!) else {
        throw contractError("Invalid tokens.txt row: \(line)")
      }
      guard result.updateValue(fields.dropLast().joined(separator: " "), forKey: id) == nil else {
        throw contractError("Duplicate token id \(id)")
      }
    }
    try require(result.count == 251, "tokens.txt must contain 251 unique ids")
    try require(result[Self.blankID] == "<blank>", "tokens.txt blank must be id 250")
    return result
  }

  private func requireShape(_ model: MLModel, feature: String, expected: [Int], output: Bool) throws {
    let descriptions = output ? model.modelDescription.outputDescriptionsByName
      : model.modelDescription.inputDescriptionsByName
    let actual = descriptions[feature]?.multiArrayConstraint?.shape.map(\.intValue)
    try require(actual == expected, "\(feature) shape was \(String(describing: actual)); expected \(expected)")
  }

  private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw contractError(message) }
  }

  private func contractError(_ message: String) -> NSError {
    NSError(domain: "QuranCoreMLContract", code: 1,
      userInfo: [NSLocalizedDescriptionKey: message])
  }
}
