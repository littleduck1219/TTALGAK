// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TTALGAK",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TTALGAK", targets: ["TTALGAK"])],
    targets: [.executableTarget(name: "TTALGAK")]
)
