// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CompileXcodeProject",
  platforms: [
    .macOS(.v10_13),
  ],
  dependencies: [
    // Dependencies declare other packages that this package depends on.
    // .package(url: /* package url */, from: "1.0.0"),
    .package(url: "https://github.com/kareman/SwiftShell.git", from: "5.0.0"),
    .package(url: "https://github.com/KeithPiTsui/PaversSPM.git", from: "2.0.1"),
    
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "CompileXcodeProject",
      dependencies: ["SwiftShell", "PaversFRP"]),
    ]
)
