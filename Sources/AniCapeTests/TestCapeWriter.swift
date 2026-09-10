import Foundation
import AppKit
import CapeKit

func testStripIsFramesStackedTopToBottomAndTiffLZW() throws {
    var red = [UInt8](repeating: 0, count: 2 * 1 * 4)
    for i in 0..<2 { red[i * 4 + 0] = 255; red[i * 4 + 3] = 255 }
    var green = [UInt8](repeating: 0, count: 2 * 1 * 4)
    for i in 0..<2 { green[i * 4 + 1] = 255; green[i * 4 + 3] = 128 }
    let cur = CapeCursor(identifier: "com.apple.coregraphics.Arrow", frameDuration: 0.1,
                         frameWidthPx: 2, frameHeightPx: 1, hotspotX: 0, hotspotY: 0,
                         frames: [red, green])
    let tiff = try CapeWriter.data(for: cur)
    let rep = try Harness.unwrap(NSBitmapImageRep(data: tiff), "decode tiff")
    Harness.eq(rep.pixelsWide, 2, "pixelsWide")
    Harness.eq(rep.pixelsHigh, 2, "pixelsHigh")   // 1px high × 2 frames
    let bd = rep.bitmapData!
    var px = [UInt8](); px.append(contentsOf: UnsafeBufferPointer(start: bd, count: 16))
    Harness.eq(Array(px[0..<4]), [255, 0, 0, 255], "row0 px0 = frame 0 red")
    Harness.eq(Array(px[4..<8]), [255, 0, 0, 255], "row0 px1 = frame 0 red")
    Harness.eq(Array(px[8..<12]), [0, 255, 0, 128], "row1 px0 = frame 1 green")
}

func testWriteProducesReadableXMLFile() throws {
    var red = [UInt8](repeating: 0, count: 4 * 2 * 4)
    for i in 0..<4 { red[i * 4 + 0] = 255; red[i * 4 + 3] = 255 }
    let cur = CapeCursor(identifier: "com.apple.cursor.2", frameDuration: 0.05,
                         frameWidthPx: 4, frameHeightPx: 2, hotspotX: 1, hotspotY: 1,
                         frames: [red])
    let doc = CapeDocument(name: "p", author: "a", identifier: "local.anicap.p",
                           cursors: [cur.identifier: cur])
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("out.cape")
    try CapeWriter.write(document: doc, to: url)
    Harness.check(FileManager.default.fileExists(atPath: url.path), "output file exists")
    let head = try Data(contentsOf: url).prefix(80)
    Harness.check(head.starts(with: Data("<?xml".utf8)), "file starts with <?xml")
}
