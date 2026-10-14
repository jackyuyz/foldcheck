// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TestsKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TestsKit",
            targets: ["TestsKit"]
        ),
    ],
    dependencies: [
        .package(path: "../FoldKit"),
        .package(path: "../HingeAnalysis")
    ],
    targets: [
        .target(
            name: "TestsKit",
            dependencies: ["FoldKit", "HingeAnalysis"]
        ),
        .testTarget(
            name: "TestsKitTests",
            dependencies: ["TestsKit"]
        ),
    ]
)
