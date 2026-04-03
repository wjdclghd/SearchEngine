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
        
    ],
    targets: [
        .target(
            name: "SearchEngine",
            dependencies: [
                
            ],
            path: "Sources/SearchEngine",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "SearchEngineTests",
            dependencies: [
                "SearchEngine",
                
            ],
            path: "Tests/SearchEngineTests",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
