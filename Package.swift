// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacWisper",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "MacWisper", targets: ["MacWisper"])],
    targets: [
        .binaryTarget(name: "CTranscribe", path: "vendor/TranscribeCpp.xcframework"),
        .executableTarget(
            name: "MacWisper",
            dependencies: ["CTranscribe"],
            path: "Sources/MacWisper",
            linkerSettings: [.linkedFramework("Speech"), .linkedFramework("AVFoundation"), .linkedFramework("ApplicationServices")]
        ),
        .testTarget(name: "MacWisperTests", dependencies: ["MacWisper"])
    ]
)
