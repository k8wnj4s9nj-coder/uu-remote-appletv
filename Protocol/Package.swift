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
    dependencies: [
        // Provides tvOS 17+ WebRTC binary (LiveKitWebRTC / LKRTC* symbols).
        .package(url: "https://github.com/livekit/webrtc-xcframework", from: "125.0.0")
    ],
    targets: [
        .target(
            name: "UURemoteProtocol",
            dependencies: [
                .product(name: "LiveKitWebRTC", package: "webrtc-xcframework")
            ],
            path: "Sources/UURemoteProtocol"
        )
    ]
)
