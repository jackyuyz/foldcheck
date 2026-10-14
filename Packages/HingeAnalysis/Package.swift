// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HingeAnalysis",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HingeAnalysis",
            targets: ["HingeAnalysis"]
        ),
    ],
    dependencies: [
        .package(path: "../FoldKit")
    ],
    targets: [
        .target(
            name: "HingeAnalysis",
            dependencies: ["FoldKit"]
        ),
        .testTarget(
            name: "HingeAnalysisTests",
            dependencies: ["HingeAnalysis"]
        ),
    ]
)
