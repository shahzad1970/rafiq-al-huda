import Flutter
@testable import Runner
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testMicrophonePermissionDescriptionIsPresent() {
    let description = Bundle.main.object(forInfoDictionaryKey: "NSMicrophoneUsageDescription") as? String
    XCTAssertNotNil(description)
    XCTAssertFalse(description?.isEmpty ?? true)
  }

  func testStreamingFbankMatchesPinnedReference() throws {
    let extractor = QuranFbankExtractor()
    XCTAssertEqual(extractor.featureDimension, 80)
    XCTAssertEqual(extractor.frameShiftSeconds, 0.01, accuracy: 0.000_001)

    var samples: [Int16] = []
    samples.reserveCapacity(1600)
    for index in 0..<1600 {
      let ramp = index * 997
      let offset = (index % 17) * 113
      let value = ((ramp + offset) % 50_000) - 25_000
      samples.append(Int16(value))
    }
    for range in [0..<257, 257..<766, 766..<1600] {
      var data = Data(capacity: range.count * 2)
      for index in range {
        var sample = samples[index].littleEndian
        withUnsafeBytes(of: &sample) { data.append(contentsOf: $0) }
      }
      try extractor.acceptPCM16LEData(data)
    }

    XCTAssertEqual(extractor.numberOfFramesReady, 9)
    extractor.finishInput()
    XCTAssertEqual(extractor.numberOfFramesReady, 10)

    let bins = [0, 1, 2, 17, 39, 79]
    let expected: [Int: [Float]] = [
      0: [-3.287431, -2.86835861, -2.23133469, 0.147867143, 1.35552812, 3.98124623],
      4: [-7.08010006, -6.31077814, -6.29618692, -2.77769423, -0.135287285, 4.12911415],
      9: [-4.39046383, -3.1471138, -2.61561108, -2.18440199, 0.621545136, 4.04035521],
    ]
    for (frameIndex, reference) in expected {
      let data = try extractor.frameFloat32Data(at: frameIndex)
      XCTAssertEqual(data.count, 80 * MemoryLayout<Float>.size)
      data.withUnsafeBytes { raw in
        let values = raw.bindMemory(to: Float.self)
        for (offset, bin) in bins.enumerated() {
          XCTAssertEqual(values[bin], reference[offset], accuracy: 0.000_1)
        }
      }
    }
  }

}
