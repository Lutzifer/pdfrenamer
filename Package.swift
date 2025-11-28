// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "pdfrenamer",
  platforms: [.macOS(.v15)],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    .package(url: "https://github.com/mxcl/Path.swift.git", from: "1.4.1"),
  ],
  targets: [
    .executableTarget(
      name: "pdfrenamer",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Path", package: "Path.swift"),
      ]
    )
  ]
)
