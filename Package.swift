// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleScreenshot",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "SimpleScreenshot", targets: ["SimpleScreenshot"])],
    targets: [
        .executableTarget(
            name: "SimpleScreenshot",
            path: "Sources/SimpleScreenshot",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
