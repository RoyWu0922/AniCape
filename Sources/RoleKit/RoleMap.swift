/// GUI 里可指派的 macOS 光标槽位（中英文规范名 + identifier）。
public struct MacRole: Equatable {
    public let name: String
    /// 英文规范名，与 `name` 一样是角色*数据*（GUI 切到英文时显示它）。
    /// 它同时也是 `RoleMap.table` 里该角色的英文别名，测试守卫着这一点——
    /// 改这里就得同步 `table`，否则英文文件名会识别不出来。
    public let englishName: String
    public let identifier: String
    public init(name: String, englishName: String, identifier: String) {
        self.name = name
        self.englishName = englishName
        self.identifier = identifier
    }
}

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

extension RoleMap {
    /// 13 个可指派槽位。**显式有序字面量**：私有 `table` 是 Dictionary（无序），
    /// 不能拿来驱动 UI 列表顺序，故此处独立维护并加测试守卫。
    public static let assignableRoles: [MacRole] = [
        MacRole(name: "正常选择", englishName: "Normal", identifier: "com.apple.coregraphics.Arrow"),
        MacRole(name: "帮助选择", englishName: "Help", identifier: "com.apple.cursor.40"),
        MacRole(name: "后台运行", englishName: "Working", identifier: "com.apple.cursor.4"),
        MacRole(name: "忙", englishName: "Busy", identifier: "com.apple.coregraphics.Wait"),
        MacRole(name: "精确选择", englishName: "Precision", identifier: "com.apple.cursor.7"),
        MacRole(name: "文本选择", englishName: "Text", identifier: "com.apple.coregraphics.IBeam"),
        MacRole(name: "垂直调整", englishName: "Vertical", identifier: "com.apple.cursor.32"),
        MacRole(name: "水平调整", englishName: "Horizontal", identifier: "com.apple.cursor.28"),
        MacRole(name: "沿对角线调整1", englishName: "Diagonal1", identifier: "com.apple.cursor.34"),
        MacRole(name: "沿对角线调整2", englishName: "Diagonal2", identifier: "com.apple.cursor.30"),
        MacRole(name: "移动", englishName: "Move", identifier: "com.apple.coregraphics.Move"),
        MacRole(name: "链接选择", englishName: "Link", identifier: "com.apple.cursor.2"),
        MacRole(name: "不可用", englishName: "Unavailable", identifier: "com.apple.cursor.3"),
    ]

    /// identifier → 中文规范名（GUI 显示用）；未知返回 nil。
    public static func displayName(forIdentifier id: String) -> String? {
        assignableRoles.first { $0.identifier == id }?.name
    }

    /// 该文件名是否为「无 mac 槽」角色。
    public static func isSkipped(_ baseName: String) -> Bool {
        skippedRoleNames.contains(baseName)
    }
}
