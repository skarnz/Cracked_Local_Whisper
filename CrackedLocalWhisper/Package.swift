// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CrackedLocalWhisper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CrackedLocalWhisper", targets: ["CrackedLocalWhisper"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "CrackedLocalWhisper",
            dependencies: [
                "WhisperKit",
                "KeyboardShortcuts"
            ],
            path: ".",
            exclude: ["Resources"],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        )
    ]
)
