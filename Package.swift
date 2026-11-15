// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MyNotchApp",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NotchKit"),
        .executableTarget(name: "MyNotchApp", dependencies: ["NotchKit"]),
        .testTarget(name: "NotchKitTests", dependencies: ["NotchKit"]),
    ],
    swiftLanguageModes: [.v6]
)
