// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GhostBar",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "GhostBar", targets: ["GhostBar"])],
    targets: [
        .target(name: "MenuBarBridge", path: "Sources/MenuBarBridge", publicHeadersPath: "include"),
        .executableTarget(name: "GhostBar", dependencies: ["MenuBarBridge"], path: "Sources/GhostBar"),
        .testTarget(name: "GhostBarTests", dependencies: ["GhostBar"], path: "Tests")
    ]
)
