// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AeroBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "AeroBar",
            targets: ["AeroBar"]
        ),
    ],
    dependencies: [
        // Add dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "AeroBar",
            dependencies: [],
            path: "AeroBar/Sources/AeroBar"
        ),
    ]
)
