// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmurfAudio",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SmurfAudio",
            path: "Sources/SmurfAudio"
        ),
        .testTarget(
            name: "SmurfAudioTests",
            dependencies: ["SmurfAudio"],
            path: "Tests/SmurfAudioTests",
            swiftSettings: [
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ]
)
