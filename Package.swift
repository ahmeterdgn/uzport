// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "UzPort",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "UzPort", targets: ["UzPort"]),
        .library(name: "PortCore", targets: ["PortCore"]),
    ],
    targets: [
        .target(name: "PortCore"),
        .executableTarget(name: "UzPort", dependencies: ["PortCore"]),
        .testTarget(name: "PortCoreTests", dependencies: ["PortCore"]),
    ]
)
