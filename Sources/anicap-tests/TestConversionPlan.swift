import Foundation
import Core

/// 夹具目录：Normal(可识别) / 手写(无槽) / whatever(未识别) / 坏(损坏) / note.txt(非ani) / sub/(子目录)
private func planFixtureDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let img = DIBImageBuilder.curImage(width: 2, height: 1, rgba: [UInt8]([255, 0, 0, 255, 255, 0, 0, 255]))
    let ani = ANIBuilder.build(frames: [[(w: UInt8(2), h: UInt8(1), hsx: UInt16(0), hsy: UInt16(0), image: img)]],
                               declaredFrames: 1, jiffies: 10, rates: nil, seq: nil)
    try ani.write(to: dir.appendingPathComponent("Normal.ani"))
    try ani.write(to: dir.appendingPathComponent("手写.ani"))
    try ani.write(to: dir.appendingPathComponent("whatever.ani"))
    try Data([0x00, 0x01, 0x02, 0x03]).write(to: dir.appendingPathComponent("坏.ani"))
    try Data("x".utf8).write(to: dir.appendingPathComponent("note.txt"))
    let sub = dir.appendingPathComponent("sub", isDirectory: true)
    try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
    try ani.write(to: sub.appendingPathComponent("Move.ani"))
    return dir
}

func testPlanClassifiesFourStates() throws {
    let dir = try planFixtureDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let items = try Converter.plan(folder: dir)
    Harness.eq(items.count, 4, "只收集直接子项里的 4 个 .ani")
    let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.fileName, $0) })
    Harness.check(byName["Normal.ani"]?.status == .ready("com.apple.coregraphics.Arrow"), "Normal → ready(Arrow)")
    Harness.check(byName["手写.ani"]?.status == .needsAssignment(.noMacSlot), "手写 → noMacSlot")
    Harness.check(byName["whatever.ani"]?.status == .needsAssignment(.unrecognized), "whatever → unrecognized")
    var isError = false
    if case .error = byName["坏.ani"]?.status { isError = true }
    Harness.check(isError, "坏.ani → .error")
    Harness.eq(byName["Normal.ani"]?.displayName, "Normal", "displayName 去扩展名")
}

func testPlanSortsFiltersAndDoesNotRecurse() throws {
    let dir = try planFixtureDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let names = try Converter.plan(folder: dir).map { $0.fileName }
    Harness.eq(names, names.sorted(), "按文件名升序")
    Harness.check(!names.contains("note.txt"), "非 .ani 被忽略")
    Harness.check(!names.contains("Move.ani"), "子目录不递归")
}

func testPlanDecodesEveryDecodableItemOnce() throws {
    let dir = try planFixtureDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let items = try Converter.plan(folder: dir)
    for it in items where it.fileName != "坏.ani" {
        Harness.notNil(it.cursor, "\(it.fileName) 可解码 → cursor 非 nil")
    }
    let normal = items.first { $0.fileName == "Normal.ani" }
    Harness.eq(normal?.cursor?.frames.count, 1, "1 个显示步")
    Harness.eq(normal?.cursor?.frameWidthPx, 2, "宽 2")
    Harness.check(items.first { $0.fileName == "坏.ani" }?.cursor == nil, "坏文件 cursor 为 nil")
}

func testPlanFilesSortsGivenURLs() throws {
    let dir = try planFixtureDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let files = [dir.appendingPathComponent("whatever.ani"), dir.appendingPathComponent("Normal.ani")]
    let items = Converter.plan(files: files)
    Harness.eq(items.map { $0.fileName }, ["Normal.ani", "whatever.ani"], "plan(files:) 也按文件名升序")
}
