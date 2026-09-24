// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Paper",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Paper", targets: ["Paper"])],
    targets: [
        .target(name: "PaperCore"),
        .executableTarget(name: "Paper", dependencies: ["PaperCore"]),
        .testTarget(name: "PaperCoreTests", dependencies: ["PaperCore"]),
        .testTarget(name: "PaperTests", dependencies: ["Paper"]),
    ]
)

