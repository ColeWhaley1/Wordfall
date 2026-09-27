// swift-tools-version: 5.10
// The game logic (Wordfall/Engine) is compiled into the iOS app by the Xcode
// project and also exposed here as a package so it can be tested with
// `swift test` on any machine, including Linux, without a simulator.
import PackageDescription

let package = Package(
    name: "WordfallCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WordfallCore", targets: ["WordfallCore"]),
    ],
    targets: [
        .target(
            name: "WordfallCore",
            path: "Wordfall/Engine"
        ),
        .testTarget(
            name: "WordfallCoreTests",
            dependencies: ["WordfallCore"],
            path: "Tests/WordfallCoreTests"
        ),
    ]
)
