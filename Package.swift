// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DimiCheckMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DimiCheckMac", targets: ["DimiCheckMacApp"]),
        .library(name: "DimiCheckMacCore", targets: ["DimiCheckMacCore"])
    ],
    targets: [
        .target(name: "DimiCheckMacCore"),
        .executableTarget(
            name: "DimiCheckMacApp",
            dependencies: ["DimiCheckMacCore"]
        ),
        .testTarget(
            name: "DimiCheckMacCoreTests",
            dependencies: ["DimiCheckMacCore"]
        )
    ]
)
