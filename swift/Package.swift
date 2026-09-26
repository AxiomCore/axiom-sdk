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
            dependencies: ["AxiomRuntime"]
        ),

        // 🚀 THE MAGIC: SPM downloads the exact same zip as Flutter!
        .binaryTarget(
            name: "AxiomRuntime",
            url: "https://github.com/AxiomCore/AxiomCore/releases/download/v0.148.2/AxiomRuntime.xcframework.zip",
            // IMPORTANT: SPM requires a checksum. You must run:
            // `shasum -a 256 AxiomRuntime.xcframework.zip` and paste the result here!
            checksum: "9c9e0d21bd5b91bc38a858ca241ce664e6b1a07665843a4d96af813cd1fe2238"
        ),
        .testTarget(
            name: "AxiomTests",
            dependencies: ["Axiom"]
        ),
    ]
)
