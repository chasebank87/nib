// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Nib",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "NibDomain", targets: ["NibDomain"]),
        .library(name: "NibServices", targets: ["NibServices"]),
        .library(name: "NibCoreBridge", targets: ["NibCoreBridge"]),
        .library(name: "NibUI", targets: ["NibUI"]),
    ],
    targets: [
        .systemLibrary(
            name: "CNibCore",
            path: "ZigCore/include"
        ),
        .target(
            name: "NibDomain",
            path: "Domain"
        ),
        .target(
            name: "NibCoreBridge",
            dependencies: [
                "CNibCore",
                "NibDomain",
            ],
            path: "CoreBridge",
            linkerSettings: [
                .linkedLibrary("nib_core"),
            ]
        ),
        .target(
            name: "NibServices",
            dependencies: [
                "NibDomain",
                "NibCoreBridge",
            ],
            path: "Services"
        ),
        .target(
            name: "NibUI",
            dependencies: [
                "NibDomain",
                "NibServices",
            ],
            path: "UI"
        ),
        .testTarget(
            name: "NibDomainTests",
            dependencies: [
                "NibDomain",
                "NibServices",
            ],
            path: "Tests/DomainTests"
        ),
        .testTarget(
            name: "NibCoreBridgeTests",
            dependencies: [
                "NibCoreBridge",
            ],
            path: "Tests/CoreBridgeTests"
        ),
    ]
)
