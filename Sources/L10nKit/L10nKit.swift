import Foundation

/// GUI 语言。默认中文（与既有行为一致），由用户在底栏手动切换，
/// 不跟随系统语言。
public enum Language: String, CaseIterable, Identifiable, Sendable {
    case zh
    case en

    public var id: String { rawValue }

    /// 语言自己的名字——切换器里用它显示，两种语言下都读得懂。
    public var selfName: String {
        switch self {
        case .zh: return "中文"
        case .en: return "English"
        }
    }
}

/// 界面文案表。
///
/// 这里是手写的字符串表，不是 `.xcstrings` / `.lproj`：本项目是纯 SwiftPM
/// 加命令行工具链，没有 Xcode 构建系统，而字符串目录恰恰由 Xcode 编译，
/// `swift build` 不会处理它。理由和测试用手写 harness 而不是 XCTest 一样。
///
/// 表里只放**界面**文案。光标角色名走 `MacRole`（见 `RoleKit`），命令行
/// 输出不走这里——它的中文是既定行为。
public enum L10n {
    public enum Key: String, CaseIterable, Sendable {
        case nameField, authorField, convert, clear, outputLabel, chooseOutput
        case analyzing, success, revealFinder, openMousecape, failed, idleCount
        case dropTitle, dropClick
        case exclude, rowConflict, unavailable, framesSize
        case noMacSlot, unrecognized
        case previewCaption, noPreview, selectToPreview
        case conflictLine, listSeparator, rolePickerLabel, languageLabel
    }

    /// 带占位符的条目用 `%d` / `%@`，由调用处以 `String(format:)` 填充。
    private static let zh: [Key: String] = [
        .nameField: "名称",
        .authorField: "作者",
        .convert: "转换",
        .clear: "清空",
        .outputLabel: "输出",
        .chooseOutput: "选择…",
        .analyzing: "分析中…",
        .success: "✅ 已写出 %d 个光标 → %@",
        .revealFinder: "在 Finder 中显示",
        .openMousecape: "用 Mousecape 打开",
        .failed: "❌ %@",
        .idleCount: "有效光标 %d 个",
        .dropTitle: "拖入 .ani 或文件夹",
        .dropClick: "也可以点这里选择",
        .exclude: "不纳入",
        .rowConflict: "与另一文件指向同一槽位：转换时后者覆盖前者",
        .unavailable: "不可用",
        .framesSize: "%d 帧 · %dx%d",
        .noMacSlot: "⚠️ 无 mac 槽",
        .unrecognized: "⚠️ 未识别",
        .previewCaption: "%d 帧 · %dx%d · 热点 (%d, %d) · %dms/帧",
        .noPreview: "无法预览：%@",
        .selectToPreview: "选中一行查看预览",
        .conflictLine: "⚠️ %@ 指向同一槽位 %@：转换时按文件名升序后者覆盖前者",
        .listSeparator: "、",
        .rolePickerLabel: "角色",
        .languageLabel: "语言",
    ]

    private static let en: [Key: String] = [
        .nameField: "Name",
        .authorField: "Author",
        .convert: "Convert",
        .clear: "Clear",
        .outputLabel: "Output",
        .chooseOutput: "Choose…",
        .analyzing: "Analyzing…",
        .success: "✅ Wrote %d cursors → %@",
        .revealFinder: "Reveal in Finder",
        .openMousecape: "Open in Mousecape",
        .failed: "❌ %@",
        .idleCount: "%d cursors ready",
        .dropTitle: "Drop .ani or a folder",
        .dropClick: "or click here to choose",
        .exclude: "Exclude",
        .rowConflict: "Assigned to the same slot as another file — the later one wins",
        .unavailable: "Unavailable",
        .framesSize: "%d frames · %dx%d",
        .noMacSlot: "⚠️ No macOS slot",
        .unrecognized: "⚠️ Unrecognized",
        .previewCaption: "%d frames · %dx%d · hotspot (%d, %d) · %dms/frame",
        .noPreview: "Cannot preview: %@",
        .selectToPreview: "Select a row to preview",
        .conflictLine: "⚠️ %@ assigned to the same slot %@ — later files overwrite earlier ones",
        .listSeparator: ", ",
        .rolePickerLabel: "Role",
        .languageLabel: "Language",
    ]

    /// 查表。中文表是全集，英文表缺条目时回落到中文，再回落到键名，
    /// 所以漏译只会露出中文，不会露出空白。
    public static func text(_ key: Key, _ language: Language) -> String {
        let table = language == .zh ? zh : en
        return table[key] ?? zh[key] ?? key.rawValue
    }
}
