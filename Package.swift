// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "IssueTree",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "IssueTreeCore"),
        .executableTarget(name: "IssueTree", dependencies: ["IssueTreeCore"]),
        .testTarget(name: "IssueTreeCoreTests", dependencies: ["IssueTreeCore"]),
    ]
)
