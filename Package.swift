// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "push",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "push"
        )
    ]
)
