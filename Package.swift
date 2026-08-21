// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TTALGAK",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TTALGAK", targets: ["TTALGAK"])],
    targets: [
        .target(name: "SpearGameCore"),
        .executableTarget(name: "TTALGAK", dependencies: ["SpearGameCore"], exclude: ["Resources", "StickmanMotionAssets.swift"]),
        .testTarget(name: "SpearGameCoreTests", dependencies: ["SpearGameCore"], path: "Tests", exclude: ["verify_project.py"])
    ]
)
