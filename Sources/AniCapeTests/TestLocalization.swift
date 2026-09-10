import Foundation
import L10nKit
import RoleKit

// 界面文案表的守卫。文案本身没法"测对错"，但几类会悄悄坏掉的东西可以：
// 漏翻（英文表缺条目 → 回落到中文）、占位符两边不一致（String(format:) 读到
// 不存在的参数）、以及 `String(format:)` 拿 Swift `Int` 配 `%d` 时格式化的
// 实际结果（不是"非空"就算过——那正是会掩盖问题的断言）。
//
// 角色名另测：`englishName` 与 `RoleMap.table` 的英文别名是各存一份的，
// 靠测试锁住两边不漂移。

/// 每个键在两种语言下都有非空文案。
func testEveryKeyHasTextInBothLanguages() {
    for key in L10n.Key.allCases {
        for lang in Language.allCases {
            Harness.check(!L10n.text(key, lang).isEmpty,
                          "\(key.rawValue) 在 \(lang.rawValue) 下非空")
        }
    }
}

/// 中文表里含汉字的条目，英文必须不同——否则就是漏翻后原样回落到中文，
/// 界面上完全看不出来。纯符号/纯占位符的条目（如 `❌ %@`）不在此列。
func testEnglishIsActuallyTranslated() {
    for key in L10n.Key.allCases {
        let zh = L10n.text(key, .zh)
        let en = L10n.text(key, .en)
        guard zh.unicodeScalars.contains(where: { $0.value > 0x2E80 }) else { continue }
        Harness.check(zh != en, "\(key.rawValue) 英文与中文不同（未被漏翻）")
    }
}

/// 两种语言的占位符个数必须一致，否则格式化会错位或多读参数。
func testPlaceholderCountsMatchAcrossLanguages() {
    for key in L10n.Key.allCases {
        Harness.eq(countPlaceholders(L10n.text(key, .en)),
                   countPlaceholders(L10n.text(key, .zh)),
                   "\(key.rawValue) 占位符个数一致")
    }
}

/// 真正格式化一遍，比对结果。覆盖所有不含 emoji 的带参模板。
func testTemplatesFormatToExpectedStrings() {
    func fmt(_ key: L10n.Key, _ lang: Language, _ args: [CVarArg]) -> String {
        String(format: L10n.text(key, lang), arguments: args)
    }
    Harness.eq(fmt(.framesSize, .zh, [3, 32, 24]), "3 帧 · 32x24", "中文帧数行")
    Harness.eq(fmt(.framesSize, .en, [3, 32, 24]), "3 frames · 32x24", "英文帧数行")
    Harness.eq(fmt(.idleCount, .zh, [7]), "有效光标 7 个", "中文有效数")
    Harness.eq(fmt(.idleCount, .en, [7]), "7 cursors ready", "英文有效数")
    Harness.eq(fmt(.previewCaption, .zh, [3, 32, 24, 5, 5, 100]),
               "3 帧 · 32x24 · 热点 (5, 5) · 100ms/帧", "中文预览说明")
    Harness.eq(fmt(.previewCaption, .en, [3, 32, 24, 5, 5, 100]),
               "3 frames · 32x24 · hotspot (5, 5) · 100ms/frame", "英文预览说明")
    Harness.eq(fmt(.noPreview, .zh, ["x.ani"]), "无法预览：x.ani", "中文无法预览")
    Harness.eq(fmt(.noPreview, .en, ["x.ani"]), "Cannot preview: x.ani", "英文无法预览")
}

/// emoji 前缀的模板不做逐字比对——变体选择符（U+FE0F）在不同源里未必一致，
/// 逐字比对会退化成在测源码编码而不是测格式化。改为断言替换值都进去了、
/// 且没有占位符残留，这同样能抓住参数错位。
func testEmojiTemplatesSubstituteWithoutLeftovers() {
    func fmt(_ key: L10n.Key, _ lang: Language, _ args: [CVarArg]) -> String {
        String(format: L10n.text(key, lang), arguments: args)
    }
    func assertSubstitutes(_ key: L10n.Key, _ lang: Language,
                           _ args: [CVarArg], _ needles: [String]) {
        let got = fmt(key, lang, args)
        let label = "\(key.rawValue)/\(lang.rawValue)"
        for needle in needles {
            Harness.check(got.contains(needle), "\(label) 结果含「\(needle)」— got \(got)")
        }
        Harness.check(!got.contains("%d") && !got.contains("%@"),
                      "\(label) 无占位符残留 — got \(got)")
    }
    assertSubstitutes(.success, .zh, [13, "/tmp/a.cape"], ["13", "/tmp/a.cape"])
    assertSubstitutes(.success, .en, [13, "/tmp/a.cape"], ["13", "/tmp/a.cape"])
    assertSubstitutes(.failed, .zh, ["boom"], ["boom"])
    assertSubstitutes(.failed, .en, ["boom"], ["boom"])
    assertSubstitutes(.conflictLine, .zh, ["a.ani、b.ani", "com.apple.cursor.2"],
                      ["a.ani、b.ani", "com.apple.cursor.2"])
    assertSubstitutes(.conflictLine, .en, ["a.ani, b.ani", "com.apple.cursor.2"],
                      ["a.ani, b.ani", "com.apple.cursor.2"])
}

/// 语言自身名字与 `rawValue` 往返；认不出的 rawValue 必须是 nil
/// （`LanguageSettings` 靠它回落到中文）。
func testLanguageIdentityAndUnknownValue() {
    Harness.eq(Language.allCases.count, 2, "两种语言")
    for lang in Language.allCases {
        Harness.eq(Language(rawValue: lang.rawValue), lang, "\(lang.rawValue) 往返")
        Harness.check(!lang.selfName.isEmpty, "\(lang.rawValue) selfName 非空")
    }
    Harness.eq(Language.zh.selfName, "中文", "中文自称")
    Harness.eq(Language.en.selfName, "English", "英文自称")
    Harness.isNil(Language(rawValue: "fr"), "认不出的语言 → nil")
    Harness.isNil(Language(rawValue: ""), "空串 → nil")
}

/// 13 个角色的英文名非空、唯一，且仍是 `RoleMap` 认得的别名。
func testRoleEnglishNamesAreUniqueAndResolvable() {
    let roles = RoleMap.assignableRoles
    Harness.eq(roles.count, 13, "13 个可指派槽位")
    Harness.eq(Set(roles.map { $0.englishName }).count, 13, "英文名唯一")
    for role in roles {
        Harness.check(!role.englishName.isEmpty, "\(role.identifier) 英文名非空")
        Harness.eq(RoleMap.identifier(forFileName: role.englishName), role.identifier,
                   "\(role.englishName) 仍是 RoleMap 的别名")
    }
}

/// 英文名不得与 8 个跳过名相撞——撞了会让该角色的英文名变成"无 mac 槽"。
func testRoleEnglishNamesAvoidSkippedNames() {
    for role in RoleMap.assignableRoles {
        Harness.check(!RoleMap.skippedRoleNames.contains(role.englishName),
                      "\(role.englishName) 不在跳过名单里")
    }
}

// MARK: - 辅助

/// `%d` / `%@` 的个数。本项目只用这两种转换，故不必做完整的 printf 解析。
private func countPlaceholders(_ s: String) -> Int {
    var n = 0
    var prev: Character?
    for ch in s {
        if (ch == "d" || ch == "@"), prev == "%" { n += 1 }
        prev = ch
    }
    return n
}
