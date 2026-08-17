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
        .target(
            name: "NibDomain",
            path: "Domain"
        ),
        .target(
            name: "NibTreeSitterC",
            path: "ThirdParty/NibTreeSitterC",
            sources: [
                "src/runtime/lib.c",
                "src/json/parser.c",
                "src/python/parser.c",
                "src/python/scanner.c",
                "src/markdown/parser.c",
                "src/markdown/scanner.c",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("src/runtime"),
                .headerSearchPath("src/json"),
                .headerSearchPath("src/python"),
                .headerSearchPath("src/markdown"),
            ]
        ),
        .target(
            name: "NibCoreBridge",
            dependencies: [
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
                "NibTreeSitterC",
            ],
            path: "Services",
            resources: [
                .copy("Syntax/Queries"),
            ]
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
    ],
    cLanguageStandard: .c11
)
