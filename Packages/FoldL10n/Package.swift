// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FoldL10n",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "FoldL10n", targets: ["FoldL10n"]),
    ],
    targets: [
        .target(
            name: "FoldL10n",
            resources: [.process("Locales")]
        ),
        .testTarget(
            name: "FoldL10nTests",
            dependencies: ["FoldL10n"]
        ),
    ]
)
