// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JobApplicationWizard",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.15.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "JobApplicationWizard",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ],
            path: "Sources/JobApplicationWizard",
            resources: [.process("Resources")]
        )
    ]
)
