public enum RoleMap {
    // 别名（英文文件名/中文文件名）→ macOS identifier；nil 值 = 无 mac 槽，跳过。
    // 中英文系统名来自 spec §3。
    private static let table: [String: String] = [
        "正常选择": "com.apple.coregraphics.Arrow",  "Normal": "com.apple.coregraphics.Arrow",
        "帮助选择": "com.apple.cursor.40",          "Help": "com.apple.cursor.40",
        "后台运行": "com.apple.cursor.4",           "Working": "com.apple.cursor.4",
        "忙": "com.apple.coregraphics.Wait",         "Busy": "com.apple.coregraphics.Wait",
        "精确选择": "com.apple.cursor.7",           "Precision": "com.apple.cursor.7",
        "文本选择": "com.apple.coregraphics.IBeam",  "Text": "com.apple.coregraphics.IBeam",
        "垂直调整": "com.apple.cursor.32",          "Vertical": "com.apple.cursor.32",
        "水平调整": "com.apple.cursor.28",          "Horizontal": "com.apple.cursor.28",
        "沿对角线调整1": "com.apple.cursor.34",     "Diagonal1": "com.apple.cursor.34",
        "沿对角线调整2": "com.apple.cursor.30",     "Diagonal2": "com.apple.cursor.30",
        "移动": "com.apple.coregraphics.Move",       "Move": "com.apple.coregraphics.Move",
        "链接选择": "com.apple.cursor.2",           "Link": "com.apple.cursor.2",
        "不可用": "com.apple.cursor.3",             "Unavailable": "com.apple.cursor.3",
    ]

    /// 被跳过（无 mac 槽）的角色：命中这些名字 → nil（与"未识别"区分，便于打印说明）
    public static let skippedRoleNames: Set<String> = ["手写", "候选", "位置选择", "个人选择",
                                                       "Handwriting", "Alternate", "Pin", "Person"]

    public static func identifier(forFileName base: String) -> String? {
        if skippedRoleNames.contains(base) { return nil }
        return table[base]
    }

    public static func identifier(forRoleName name: String) -> String? {
        if name.contains(".") { return name }       // 直接给了 identifier
        return identifier(forFileName: name)
    }
}
