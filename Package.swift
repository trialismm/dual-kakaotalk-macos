// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DualKakaoTalk",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "dual-kakaotalk-tool", targets: ["DualKakaoTalkTool"]),
        .library(name: "DualKakaoTalkCore", targets: ["DualKakaoTalkCore"]),
    ],
    targets: [
        .target(name: "DualKakaoTalkCore"),
        .executableTarget(
            name: "DualKakaoTalkTool",
            dependencies: ["DualKakaoTalkCore"]
        ),
        .testTarget(
            name: "DualKakaoTalkCoreTests",
            dependencies: ["DualKakaoTalkCore"]
        ),
    ]
)
