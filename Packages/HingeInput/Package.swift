// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HingeInput",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "HingeInput", targets: ["HingeInput"])],
    targets: [.target(name: "HingeInput"), .testTarget(name: "HingeInputTests", dependencies: ["HingeInput"])]
)
