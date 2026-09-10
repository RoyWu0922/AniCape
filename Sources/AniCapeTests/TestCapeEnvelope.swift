import Foundation
import CapeKit

private func asDict(_ v: Any?, _ name: String) throws -> [String: Any] {
    try Harness.unwrap(v as? [String: Any], name)
}

func testEnvelopeProducesXMLPlistWithExpectedKeys() throws {
    let cur = CapeCursor(identifier: "com.apple.coregraphics.Arrow", frameDuration: 0.1,
                         frameWidthPx: 4, frameHeightPx: 2, hotspotX: 1, hotspotY: 2,
                         frames: [[UInt8](repeating: 200, count: 4 * 2 * 4)])
    let doc = CapeDocument(name: "测试包", author: "tester",
                           identifier: "local.anicap.test", cursors: [cur.identifier: cur])
    let data = try CapeEnvelope.plistData(cape: doc, tiff: [cur.identifier: Data([1, 2, 3])])
    let plist = try asDict(PropertyListSerialization.propertyList(from: data, options: [], format: nil), "root dict")
    Harness.eq(plist["MinimumVersion"] as? Double, 2.0, "MinimumVersion")
    Harness.eq(plist["CapeName"] as? String, "测试包", "CapeName")
    let curs = try asDict(plist["Cursors"], "Cursors dict")
    let c = try asDict(curs["com.apple.coregraphics.Arrow"], "Arrow cursor dict")
    Harness.eq(c["FrameCount"] as? Int, 1, "FrameCount")
    Harness.eq(c["FrameDuration"] as? Double, 0.1, "FrameDuration")
    Harness.eq(c["HotSpotX"] as? Double, 1, "HotSpotX")
    Harness.eq(c["HotSpotY"] as? Double, 2, "HotSpotY")
    Harness.eq(c["PointsWide"] as? Double, 4, "PointsWide")
    Harness.eq(c["PointsHigh"] as? Double, 2, "PointsHigh")
    let reps = try Harness.unwrap(c["Representations"] as? [Data], "Representations")
    Harness.eq(reps.count, 1, "rep count")
    Harness.eq(reps[0], Data([1, 2, 3]), "rep payload")
}
