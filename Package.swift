// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CapgoCapacitorLiveActivities",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "CapgoCapacitorLiveActivities",
            targets: ["CapgoLiveActivitiesPlugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", from: "8.0.0")
    ],
    targets: [
        .target(
            name: "CapgoLiveActivitiesPlugin",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm")
            ],
            path: "ios/Sources/CapgoLiveActivitiesPlugin"),
        .testTarget(
            name: "CapgoLiveActivitiesPluginTests",
            dependencies: ["CapgoLiveActivitiesPlugin"],
            path: "ios/Tests/CapgoLiveActivitiesPluginTests")
    ]
)
