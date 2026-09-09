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
