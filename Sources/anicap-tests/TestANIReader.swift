import Foundation
import AniKit

func testANIReaderParsesHeaderRateAndSeq() throws {
    let img = Data(repeating: 7, count: 32)
    let file = ANIBuilder.build(frames: [[(w: 4, h: 4, hsx: 2, hsy: 1, image: img)]],
                                declaredFrames: 1, jiffies: 15, rates: [15], seq: [0])
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("t.ani")
    try file.write(to: url)
    let parsed = try ANIReader.parse(url: url)
    Harness.eq(parsed.header.defaultRateJiffies, 15, "defaultRateJiffies == 15")
    Harness.eq(parsed.header.declaredFrames, 1, "declaredFrames == 1")
    Harness.eq(parsed.rates, [15], "rates == [15]")
    Harness.eq(parsed.seq, [0], "seq == [0]")
    Harness.eq(parsed.frameBodies.count, 1, "one frame body")
}

func testANIReaderRejectsNonRIFF() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("bad.ani")
    try Data("nope".utf8).write(to: url)
    do {
        _ = try ANIReader.parse(url: url)
        Harness.check(false, "non-RIFF throws .notRIFF")
    } catch let e {
        Harness.check((e as? ANIError) == .notRIFF, "non-RIFF throws .notRIFF (got \(e))")
    }
}

func testChunkLengthOversizedThrowsTruncated() throws {
    // 一个 chunk 的长度字段越界 → .truncated，而不是崩溃
    var data = Data()
    data.append(Data("RIFF".utf8)); data.append(Data([0, 0, 0, 0]))   // size 占位（解析器不用）
    data.append(Data("ACON".utf8))
    data.append(Data("zzzz".utf8))                                     // chunk id
    data.append(Data([0xF0, 0xFF, 0xFF, 0xFF]))                        // len = 0xFFFFFFF0，远超剩余字节
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("oversized.ani")
    try data.write(to: url)
    do {
        _ = try ANIReader.parse(url: url)
        Harness.check(false, "oversized chunk length throws .truncated")
    } catch let e {
        Harness.check((e as? ANIError) == .truncated, "oversized chunk length throws .truncated (got \(e))")
    }
}

func testRateBodyNotMultipleOf4ThrowsTruncated() throws {
    func riffChunk(_ id: String, _ body: [UInt8]) -> Data {
        var d = Data(id.utf8)
        var len = UInt32(body.count).littleEndian
        withUnsafeBytes(of: &len) { d.append(contentsOf: $0) }
        d.append(contentsOf: body)
        if body.count % 2 == 1 { d.append(0) }
        return d
    }
    var anih = Data(repeating: 0, count: 36)
    anih.replaceSubrange(0..<4, with: Data([36, 0, 0, 0]))   // cbSize
    anih.replaceSubrange(4..<8, with: Data([1, 0, 0, 0]))    // nFrames = 1
    var data = Data()
    data.append(Data("RIFF".utf8)); data.append(Data([0, 0, 0, 0]))
    data.append(Data("ACON".utf8))
    data.append(riffChunk("anih", Array(anih)))
    data.append(riffChunk("rate", [0x0A, 0x00]))             // 2 字节 body，非 4 的倍数 → .truncated
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("badrate.ani")
    try data.write(to: url)
    do {
        _ = try ANIReader.parse(url: url)
        Harness.check(false, "rate body not multiple of 4 throws .truncated")
    } catch let e {
        Harness.check((e as? ANIError) == .truncated, "rate body not multiple of 4 throws .truncated (got \(e))")
    }
}
