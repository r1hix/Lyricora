// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Lyricora",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Lyricora",
            targets: ["Lyricora"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Lyricora",
            dependencies: [],
            path: "Sources/Lyricora"
        ),
        .testTarget(
            name: "LyricoraTests",
            dependencies: ["Lyricora"],
            path: "Tests/LyricoraTests"
        )
    ]
)
