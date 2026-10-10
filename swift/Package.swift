// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "Axiom",
    platforms: [
        .iOS(.v13),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "Axiom",
            targets: ["Axiom", "AxiomRuntime"]
        ),
    ],
    targets: [
        // Your Swift Wrapper Code lives in the Sources/Axiom folder
        .target(
            name: "Axiom",
            dependencies: ["AxiomRuntime"],
            linkerSettings: [.linkedFramework("SystemConfiguration")]
        ),

        // 🚀 THE MAGIC: SPM downloads the exact same zip as Flutter!
        .binaryTarget(
            name: "AxiomRuntime",
            url: "https://github.com/AxiomCore/AxiomCore/releases/download/v0.148.5/AxiomRuntime.xcframework.zip",
            // IMPORTANT: SPM requires a checksum. You must run:
            // `shasum -a 256 AxiomRuntime.xcframework.zip` and paste the result here!
            checksum: "caa3e80dcb9374d633ffeb4fed3fe3797e832056154daab1f157bbfe13dbb1a5"
        ),
        .testTarget(
            name: "AxiomTests",
            dependencies: ["Axiom"]
        ),
    ]
)
