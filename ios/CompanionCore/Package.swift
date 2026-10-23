// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CompanionCore",
    defaultLocalization: "zh-Hans",
    platforms: [.iOS(.v17), .watchOS(.v10), .macOS(.v14)],
    products: [
        .library(name: "CompanionCore", targets: ["CompanionCore"]),
        .library(name: "CompanionScene", targets: ["CompanionScene"]),
    ],
    targets: [
        // Pure behaviour: weather, world state machine, calendar, events, persistence, app model.
        .target(name: "CompanionCore", resources: [.copy("Content")]),
        // SwiftUI rendering shared by the iPhone and Apple Watch apps.
        .target(name: "CompanionScene", dependencies: ["CompanionCore"], resources: [.copy("Resources/sprites.json")]),
        .testTarget(name: "CompanionCoreTests", dependencies: ["CompanionCore"]),
    ]
)
