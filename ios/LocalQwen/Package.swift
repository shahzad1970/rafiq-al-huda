// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "LocalQwen",
  platforms: [.iOS("18.0"), .macOS(.v14)],
  products: [.library(name: "LocalQwen", targets: ["LocalQwen"]),
    .executable(name: "QwenProbe", targets: ["QwenProbe"])],
  targets: [
    // Fetch this pinned, checksum-verified artifact with tool/prepare_ask_runtime.mjs.
    // A local artifact avoids URLSession/SPM download hangs on this development Mac.
    .binaryTarget(name: "llama", path: "Artifacts/build-apple/llama.xcframework"),
    .target(name: "LocalQwen", dependencies: ["llama"]),
    .executableTarget(name: "QwenProbe", dependencies: ["LocalQwen"])
  ]
)
