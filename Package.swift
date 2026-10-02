// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Murmur",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Murmur", targets: ["Murmur"])],
    targets: [
        .binaryTarget(name: "CTranscribe", path: "vendor/TranscribeCpp.xcframework"),
        .executableTarget(
            name: "Murmur",
            dependencies: ["CTranscribe"],
            path: "Sources/Murmur",
            resources: [.copy("Resources/satisfying_click.wav")],
            linkerSettings: [.linkedFramework("Speech"), .linkedFramework("AVFoundation"), .linkedFramework("ApplicationServices")]
        ),
        .testTarget(name: "MurmurTests", dependencies: ["Murmur"])
    ]
)
