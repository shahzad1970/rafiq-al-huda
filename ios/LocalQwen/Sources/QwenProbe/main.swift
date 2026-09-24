import Foundation
import LocalQwen

@main struct Probe {
  static func main() async throws {
    guard (3...5).contains(CommandLine.arguments.count) else {
      print("Usage: QwenProbe /absolute/model.gguf /absolute/evidence.json"); return
    }
    let evidence = try String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8)
    let start = Date()
    let result = try await QwenRuntime().answer(modelPath: CommandLine.arguments[1], evidence: evidence,
      qwen25: CommandLine.arguments.contains("--qwen25"),
      separatedSources: CommandLine.arguments.contains("--separated"))
    print(result)
    print("Elapsed seconds: \(Date().timeIntervalSince(start))")
  }
}
