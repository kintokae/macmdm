// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TDXMassUpdate",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TDXMassUpdate",
            path: "Sources/TDXMassUpdate"
        )
    ]
)
