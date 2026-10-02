// swift-tools-version: 5.9
import PackageDescription

// DO NOT MODIFY THIS FILE - managed by Capacitor CLI commands
let package = Package(
    name: "CapApp-SPM",
    platforms: [.iOS("16.1")],
    products: [
        .library(
            name: "CapApp-SPM",
            targets: ["CapApp-SPM"])
    ],
    dependencies: [
        .package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", exact: "8.5.2"),
        .package(name: "CapgoCapacitorLiveActivities", path: "../../../node_modules/.bun/@capgo+capacitor-live-activities@file+../node_modules/@capgo/capacitor-live-activities"),
        .package(name: "CapgoCapacitorUpdater", path: "../../../node_modules/.bun/@capgo+capacitor-updater@8.50.2+8c735c3c6e2ff3c1/node_modules/@capgo/capacitor-updater")
    ],
    targets: [
        .target(
            name: "CapApp-SPM",
            dependencies: [
                .product(name: "Capacitor", package: "capacitor-swift-pm"),
                .product(name: "Cordova", package: "capacitor-swift-pm"),
                .product(name: "CapgoCapacitorLiveActivities", package: "CapgoCapacitorLiveActivities"),
                .product(name: "CapgoCapacitorUpdater", package: "CapgoCapacitorUpdater")
            ]
        )
    ]
)
