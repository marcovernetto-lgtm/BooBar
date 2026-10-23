// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BooBar",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "BooBar", targets: ["BooBar"])],
    targets: [
        .target(name: "MenuBarBridge", path: "Sources/MenuBarBridge", publicHeadersPath: "include"),
        .executableTarget(name: "BooBar", dependencies: ["MenuBarBridge"], path: "Sources/BooBar"),
        .testTarget(name: "BooBarTests", dependencies: ["BooBar"], path: "Tests")
    ]
)
