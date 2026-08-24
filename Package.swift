// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SSRuntime",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "SurveillanceCore", targets: ["SurveillanceCore"])
    ],
    targets: [
        .target(
            name: "SurveillanceCore",
            resources: [
                .copy("Resources/contracts"),
                .copy("Resources/fixtures"),
                .copy("Resources/SPEC_PIN.txt")
            ]
        ),
        .testTarget(
            name: "SurveillanceCoreTests",
            dependencies: ["SurveillanceCore"],
            exclude: [
                "VisualLanguageTests.swift",
                "AssetIntakeTests.swift",
                "AudioProjectorTests.swift",
                "ArenaReachabilityTests.swift"
            ]
        )
    ]
)
