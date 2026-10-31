// swift-tools-version:5.9
// The game's rules as a small package, so the logic tests run anywhere Swift
// runs (including a cheap Linux machine) without Xcode. The app itself is
// built from LastPerimeter.xcodeproj.
import PackageDescription

let package = Package(
    name: "PerimeterCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PerimeterCore", targets: ["PerimeterCore"]),
    ],
    targets: [
        .target(name: "PerimeterCore", path: "LastPerimeter/Core"),
        .testTarget(
            name: "PerimeterCoreTests",
            dependencies: ["PerimeterCore"],
            path: "Tests/PerimeterCoreTests"
        ),
    ]
)
