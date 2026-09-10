// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AniCape",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "AniKit"),
        .target(name: "CapeKit"),
        .target(name: "RoleKit"),
        // 界面文案表。独立成 target 是为了让 AniCapeTests 能 import 它——
        // GUI 是 executableTarget，测试无法 import。
        .target(name: "L10nKit"),
        .target(name: "Core", dependencies: ["AniKit", "CapeKit", "RoleKit"]),
        .executableTarget(name: "AniCape", dependencies: ["AniKit", "CapeKit", "RoleKit", "Core"]),
        .executableTarget(name: "AniCapeGUI", dependencies: ["Core", "RoleKit", "CapeKit", "L10nKit"]),
        .executableTarget(name: "AniCapeTests", dependencies: ["AniKit", "CapeKit", "RoleKit", "Core", "L10nKit"]),
    ]
)
