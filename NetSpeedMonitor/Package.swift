// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "NetSpeedMonitor",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .executable(name: "NetSpeedMonitor", targets: ["NetSpeedMonitor"])
    ],
    targets: [
        .executableTarget(
            name: "NetSpeedMonitor",
            path: "NetSpeedMonitor"
        )
    ]
)
