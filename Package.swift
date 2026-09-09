// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "anicap",
    platforms: [.macOS(.v11)],
    targets: [
        .target(name: "AniKit"),
        .target(name: "CapeKit"),
        .executableTarget(name: "anicap", dependencies: ["AniKit", "CapeKit"]),
        .executableTarget(name: "anicap-tests", dependencies: ["AniKit", "CapeKit"]),
    ]
)
