// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Library",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Library",
            targets: ["Library"]
        ),
    ],
    dependencies: [
        .package(path: "../TestsKit")
    ],
    targets: [
        .target(
            name: "Library",
            dependencies: ["TestsKit"]
        ),
        .testTarget(
            name: "LibraryTests",
            dependencies: ["Library"]
        ),
    ]
)
