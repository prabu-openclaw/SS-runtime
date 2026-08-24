// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SSRuntime",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "SurveillanceCore", targets: ["SurveillanceCore"])
    ],
    targets: [
        .target(name: "SurveillanceCore"),
        .testTarget(name: "SurveillanceCoreTests", dependencies: ["SurveillanceCore"])
    ]
)
