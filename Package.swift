// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JobApplicationWizard",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "JobApplicationShared", targets: ["JobApplicationShared"]),
        .library(name: "JobApplicationWizardCore", targets: ["JobApplicationWizardCore"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.15.0"
        ),
        .package(
            url: "https://github.com/sparkle-project/Sparkle",
            from: "2.0.0"
        ),
        .package(
            url: "https://github.com/aptove/swift-sdk",
            from: "0.1.16"
        ),
        .package(
            url: "https://github.com/gonzalezreal/swift-markdown-ui",
            from: "2.4.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            from: "1.17.0"
        )
    ],
    targets: [
        .target(
            name: "JobApplicationShared",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            path: "Sources/JobApplicationShared"
        ),
        .target(
            name: "JobApplicationWizardCore",
            dependencies: [
                "JobApplicationShared",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Sparkle", package: "Sparkle", condition: .when(platforms: [.macOS])),
                .product(name: "ACP", package: "swift-sdk", condition: .when(platforms: [.macOS])),
                .product(name: "ACPModel", package: "swift-sdk", condition: .when(platforms: [.macOS])),
                .product(name: "MarkdownUI", package: "swift-markdown-ui", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/JobApplicationWizardCore"
        ),
        .executableTarget(
            name: "JobApplicationWizard",
            dependencies: [
                "JobApplicationWizardCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/JobApplicationWizard"
        ),
        .executableTarget(
            name: "DesignSystemShowcase",
            dependencies: [
                "JobApplicationWizardCore"
            ],
            path: "Sources/DesignSystemShowcase"
        ),
        .testTarget(
            name: "JobApplicationWizardTests",
            dependencies: [
                "JobApplicationWizardCore",
                "JobApplicationShared",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing")
            ],
            path: "Tests/JobApplicationWizardTests",
            exclude: ["__Snapshots__"]
        )
    ]
)
