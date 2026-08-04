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
        .target(
            name: "CoreUIBridge",
            path: "Sources/CoreUIBridge",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("CoreUI", .when(platforms: [.macOS])),
                .unsafeFlags(["-F/System/Library/PrivateFrameworks"], .when(platforms: [.macOS])),
            ]
        ),
        .target(name: "DualKakaoTalkCore", dependencies: ["CoreUIBridge"]),
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
