// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JobApplicationWizard",
    platforms: [.macOS(.v14)],
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
        )
    ],
    targets: [
        .target(
            name: "JobApplicationWizardCore",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "ACP", package: "swift-sdk"),
                .product(name: "ACPModel", package: "swift-sdk")
            ],
            path: "Sources/JobApplicationWizardCore",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "JobApplicationWizard",
            dependencies: [
                "JobApplicationWizardCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/JobApplicationWizard"
        ),
        .testTarget(
            name: "JobApplicationWizardTests",
            dependencies: [
                "JobApplicationWizardCore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Tests/JobApplicationWizardTests"
        )
    ]
)
