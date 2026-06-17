// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "myPad",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "myPad", targets: ["myPad"])
    ],
    targets: [
        .executableTarget(
            name: "myPad",
            path: "Sources/myPad"
        )
    ]
)
