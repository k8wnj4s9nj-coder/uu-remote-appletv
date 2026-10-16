// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UURemoteProtocol",
    platforms: [
        .tvOS(.v17),
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "UURemoteProtocol", targets: ["UURemoteProtocol"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "UURemoteProtocol",
            dependencies: [],
            path: "Sources/UURemoteProtocol"
        )
    ]
)
