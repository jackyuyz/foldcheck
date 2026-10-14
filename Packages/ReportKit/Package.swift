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
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.12.0"),
        .package(path: "../FoldKit"),
        .package(path: "../FoldL10n"),
        .package(path: "../TestsKit")
    ],
    targets: [
        .target(
            name: "ReportKit",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                "FoldKit",
                "FoldL10n",
                "TestsKit"
            ],
            linkerSettings: [
                .linkedLibrary("stdc++", .when(platforms: [.linux]))
            ]
        ),
        .testTarget(
            name: "ReportKitTests",
            dependencies: ["ReportKit"],
            linkerSettings: [
                .linkedLibrary("stdc++", .when(platforms: [.linux]))
            ]
        ),
    ]
)
