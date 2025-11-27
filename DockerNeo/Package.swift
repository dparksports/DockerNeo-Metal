// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DockerNeo",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DockerNeo",
            path: "Sources/DockerNeo",
            resources: [
                .process("Shaders.metal")
            ]
        )
    ]
)
