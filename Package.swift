// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "anicap",
    platforms: [.macOS(.v11)],
    targets: [
        .target(name: "AniKit"),
        .target(name: "CapeKit"),
        .executableTarget(name: "anicap", dependencies: ["AniKit", "CapeKit"]),
        .testTarget(name: "AniKitTests", dependencies: ["AniKit"]),
        .testTarget(name: "CapeKitTests", dependencies: ["CapeKit"]),
    ]
)
