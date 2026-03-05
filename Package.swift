// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "pdfrenamer",
  platforms: [.macOS(.v15)],
  products: [
      .library(name: "PDFRenamerCore", targets: ["PDFRenamerCore"]),
      .executable(name: "pdfrenamer", targets: ["pdfrenamer"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    .package(url: "https://github.com/mxcl/Path.swift.git", from: "1.4.1"),
  ],
  targets: [
    .target(
      name: "PDFRenamerCore",
      dependencies: [
        .product(name: "Path", package: "Path.swift"),
      ]
    ),
    .executableTarget(
      name: "pdfrenamer",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "PDFRenamerCore",
      ]
    )
  ]
)
