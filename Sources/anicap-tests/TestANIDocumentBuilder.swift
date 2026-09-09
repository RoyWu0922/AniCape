import Foundation
import AniKit

private func buildDoc(frames: Int, jiffies: UInt32, rates: [UInt32]?, seq: [UInt32]?) throws -> ANIDocument {
    let img = DIBImageBuilder.curImage(width: 4, height: 2,
                                       rgba: [UInt8](repeating: 200, count: 4 * 2 * 4))
    let frs = (0..<frames).map { _ in [(w: UInt8(4), h: UInt8(2), hsx: UInt16(1), hsy: UInt16(0), image: img)] }
    let file = ANIBuilder.build(frames: frs, declaredFrames: UInt32(frames), jiffies: jiffies, rates: rates, seq: seq)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".ani")
    try file.write(to: url)
    let parsed = try ANIReader.parse(url: url)
    return try ANIDocumentBuilder.build(parsed: parsed)
}

func testDefaultDurationAndIdentityOrder() throws {
    let d = try buildDoc(frames: 4, jiffies: 12, rates: nil, seq: nil)
    Harness.eq(d.displayCount, 4, "displayCount == 4")
    Harness.eq(d.displayIndices, [0, 1, 2, 3], "displayIndices == [0, 1, 2, 3]")
    Harness.check(abs(d.frameDuration - 12.0 / 60.0) < 1e-9, "frameDuration == 12/60 (default jiffies)")
}

func testRateChunkWins() throws {
    let d = try buildDoc(frames: 4, jiffies: 12, rates: [30], seq: nil)
    Harness.check(abs(d.frameDuration - 30.0 / 60.0) < 1e-9, "frameDuration == 30/60 (rate chunk wins)")
}

func testSeqExpandsWithDuplicates() throws {
    let d = try buildDoc(frames: 2, jiffies: 12, rates: nil, seq: [0, 1, 0, 1])
    Harness.eq(d.displayIndices, [0, 1, 0, 1], "displayIndices == [0, 1, 0, 1]")
    Harness.eq(d.displayCount, 4, "displayCount == 4")
}

func testTooManyFramesThrows() throws {
    Harness.assertThrows({ _ = try buildDoc(frames: 2, jiffies: 12, rates: nil, seq: Array(repeating: 0, count: 30)) },
                         "tooManyFrames(30)") {
        ($0 as? ANIDocumentError) == .tooManyFrames(30)
    }
}

func testMismatchedFrameSizeThrows() throws {
    let img4 = DIBImageBuilder.curImage(width: 4, height: 2, rgba: [UInt8](repeating: 200, count: 4 * 2 * 4))
    let img8 = DIBImageBuilder.curImage(width: 8, height: 2, rgba: [UInt8](repeating: 200, count: 8 * 2 * 4))
    let frs: [[(w: UInt8, h: UInt8, hsx: UInt16, hsy: UInt16, image: Data)]] = [
        [(w: 4, h: 2, hsx: 1, hsy: 0, image: img4)],
        [(w: 8, h: 2, hsx: 1, hsy: 0, image: img8)],
    ]
    let file = ANIBuilder.build(frames: frs, declaredFrames: 2, jiffies: 12, rates: nil, seq: nil)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".ani")
    try file.write(to: url)
    let parsed = try ANIReader.parse(url: url)
    Harness.assertThrows({ _ = try ANIDocumentBuilder.build(parsed: parsed) }, "mismatched frame sizes throw") {
        ($0 as? ANIDocumentError) == .mismatchedFrameSize(1)
    }
}

func testBadSeqThrows() throws {
    Harness.assertThrows({ _ = try buildDoc(frames: 2, jiffies: 12, rates: nil, seq: [0, 5]) }, "out-of-range seq throws") {
        ($0 as? ANIDocumentError) == .badSeq
    }
}
