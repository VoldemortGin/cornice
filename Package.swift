// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Cornice",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/Defaults.git", from: "9.0.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern.git", from: "1.1.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Cornice",
            dependencies: [
                "Defaults",
                "KeyboardShortcuts",
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                "Sparkle",
            ],
            path: "Cornice",
            exclude: [
                "Resources/Info.plist",
                "Resources/Cornice.entitlements",
            ],
            resources: [
                .process("Resources/Assets.xcassets"),
                .copy("Resources/Sounds"),
            ]
        ),
        .testTarget(
            name: "CorniceTests",
            dependencies: ["Cornice"],
            path: "CorniceTests"
        ),
    ]
)
