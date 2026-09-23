// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenVNC",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "OpenVNC", targets: ["OpenVNC"])],
    targets: [
        .systemLibrary(name: "COpenVNCCore"),
        .executableTarget(name: "OpenVNC", dependencies: ["COpenVNCCore"])
    ]
)
