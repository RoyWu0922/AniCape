// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AniCape",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "AniKit"),
        .target(name: "CapeKit"),
        .target(name: "RoleKit"),
        .target(name: "Core", dependencies: ["AniKit", "CapeKit", "RoleKit"]),
        .executableTarget(name: "AniCape", dependencies: ["AniKit", "CapeKit", "RoleKit", "Core"]),
        .executableTarget(name: "AniCapeGUI", dependencies: ["Core", "RoleKit", "CapeKit"]),
        .executableTarget(name: "AniCapeTests", dependencies: ["AniKit", "CapeKit", "RoleKit", "Core"]),
    ]
)
