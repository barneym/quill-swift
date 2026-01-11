// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QuillSwift",
    platforms: [
        .macOS(.v13)  // Ventura minimum, may increase if needed
    ],
    products: [
        // Main application
        .executable(
            name: "QuillSwift",
            targets: ["QuillSwift"]
        ),
        // Standalone markdown renderer library
        .library(
            name: "MarkdownRenderer",
            targets: ["MarkdownRenderer"]
        ),
        // Standalone syntax highlighter library
        .library(
            name: "SyntaxHighlighter",
            targets: ["SyntaxHighlighter"]
        ),
    ],
    dependencies: [
        // Markdown parsing (Apple's swift-markdown)
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0"),

        // Snapshot testing (for visual regression)
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.15.0"),
    ],
    targets: [
        // MARK: - Main Application

        .executableTarget(
            name: "QuillSwift",
            dependencies: [
                "MarkdownRenderer",
                "SyntaxHighlighter",
            ],
            path: "Sources/QuillSwift",
            resources: [
                .copy("Resources"),
            ]
        ),

        // MARK: - Markdown Renderer Library

        .target(
            name: "MarkdownRenderer",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
            ],
            path: "Sources/MarkdownRenderer"
        ),

        // MARK: - Syntax Highlighter Library

        .target(
            name: "SyntaxHighlighter",
            dependencies: [],
            path: "Sources/SyntaxHighlighter"
        ),

        // MARK: - Tests

        .testTarget(
            name: "QuillSwiftTests",
            dependencies: [
                "QuillSwift",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/QuillSwiftTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),

        .testTarget(
            name: "MarkdownRendererTests",
            dependencies: [
                "MarkdownRenderer",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/MarkdownRendererTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),

        .testTarget(
            name: "SyntaxHighlighterTests",
            dependencies: [
                "SyntaxHighlighter",
            ],
            path: "Tests/SyntaxHighlighterTests"
        ),
    ]
)
