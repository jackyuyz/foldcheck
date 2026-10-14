// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReportKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ReportKit",
            targets: ["ReportKit"]
        ),
    ],
    dependencies: [
        .package(path: "../FoldKit"),
        .package(path: "../TestsKit")
    ],
    targets: [
        .target(
            name: "ReportKit",
            dependencies: ["FoldKit", "TestsKit"]
        ),
        .testTarget(
            name: "ReportKitTests",
            dependencies: ["ReportKit"]
        ),
    ]
)
