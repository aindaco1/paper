// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Paper",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Paper", targets: ["Paper"])],
    dependencies: [
        .package(path: "shared/dust-wave-platform/desktop"),
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")
    ],
    targets: [
        .target(name: "PaperCore"),
        .executableTarget(name: "Paper", dependencies: ["PaperCore",
            .product(name: "DustWaveUpdates", package: "desktop"),
            .product(name: "DustWaveDiagnostics", package: "desktop")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "PaperCoreTests", dependencies: ["PaperCore"]),
        .testTarget(name: "PaperTests", dependencies: ["Paper"]),
    ]
)
