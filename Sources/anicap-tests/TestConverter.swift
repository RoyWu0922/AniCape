import Foundation
import Core

func testCapeCursorStackingUsesDisplayIndices() throws {
    // 2 physical frames, seq=[0,1,0,1] → 4 display steps
    let red = [UInt8]([255, 0, 0, 255, 255, 0, 0, 255])
    let blue = [UInt8]([0, 0, 255, 255, 0, 0, 255, 255])
    let frs = [DIBImageBuilder.curImage(width: 2, height: 1, rgba: red),
               DIBImageBuilder.curImage(width: 2, height: 1, rgba: blue)]
        .map { [(w: UInt8(2), h: UInt8(1), hsx: UInt16(0), hsy: UInt16(0), image: $0)] }
    let file = ANIBuilder.build(frames: frs, declaredFrames: 2, jiffies: 10, rates: nil, seq: [0, 1, 0, 1])
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("a.ani")
    try file.write(to: url)
    let cur = try Converter.capeCursor(fromANI: url, identifier: "com.apple.cursor.2")
    Harness.eq(cur.frames.count, 4, "display step count")
    Harness.eq(Array(cur.frames[0][0..<4]), [255, 0, 0, 255], "step0 = physical frame0 (red)")
    Harness.eq(Array(cur.frames[1][0..<4]), [0, 0, 255, 255], "step1 = physical frame1 (blue)")
    Harness.eq(Array(cur.frames[3][0..<4]), [0, 0, 255, 255], "step3 = physical frame1 again (blue)")
}

func testSlugStripsNonAlphanumerics() {
    Harness.eq(Converter.slug("Kal'tsit — Cur"), "kal-tsit-cur", "punctuation/space/em-dash folded")
    Harness.eq(Converter.slug("指针"), "cape", "CJK not ASCII-alnum → cape")
}

// Controller-authored (ruling T8-3): pack orchestration coverage.
func testPackSkipsUnknownAndSubdirsAndWritesCape() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let img = DIBImageBuilder.curImage(width: 2, height: 1, rgba: [UInt8]([255, 0, 0, 255, 255, 0, 0, 255]))
    let ani = ANIBuilder.build(frames: [[(w: UInt8(2), h: UInt8(1), hsx: UInt16(0), hsy: UInt16(0), image: img)]],
                               declaredFrames: 1, jiffies: 10, rates: nil, seq: nil)
    func write(_ name: String) throws { try ani.write(to: dir.appendingPathComponent(name)) }
    try write("Normal.ani")
    try write("Busy.ani")
    try write("手写.ani")      // no-mac-slot role → skipped
    try write("whatever.ani")  // unknown → skipped
    let sub = dir.appendingPathComponent("sub", isDirectory: true)
    try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
    try ani.write(to: sub.appendingPathComponent("Move.ani"))   // subdir child → must NOT be packed
    let out = dir.appendingPathComponent("out.cape")
    let res = try Converter.pack(folder: dir, outURL: out, author: "tester", name: "packtest")
    Harness.eq(res.cursors, 2, "Normal+Busy packed, subdir child excluded")
    Harness.check(res.skipped.contains("手写.ani"), "skipped role reported")
    Harness.check(res.skipped.contains("whatever.ani"), "unknown reported")
    let head = try Data(contentsOf: out).prefix(80)
    Harness.check(head.starts(with: Data("<?xml".utf8)), "pack output is xml cape")
}
