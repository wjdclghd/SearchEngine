// swift-tools-version: 5.9
//
//  Package.swift
//  SearchEngine
//
//  Created by jch on 3/27/26.
//

import PackageDescription

let package = Package(
    name: "SearchEngine",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SearchEngine",
            targets: ["SearchEngine"]
        )
    ],
    dependencies: [
//        .package(url: "https://github.com/realm/realm-swift.git", from: "20.0.4")
    ],
    targets: [
        .target(
            name: "SearchEngine",
            dependencies: [
//                .product(name: "RealmSwift", package: "realm-swift")
            ],
            path: "Sources/SearchEngine"
        ),
        .testTarget(
            name: "SearchEngineTests",
            dependencies: [
                "SearchEngine",
//                .product(name: "RealmSwift", package: "realm-swift")
            ],
            path: "Tests/SearchEngineTests"
        )
    ]
)
