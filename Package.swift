// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AulaDriver",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AulaKit",
            targets: ["AulaKit"]
        ),
        .executable(
            name: "aula-cli",
            targets: ["aula-cli"]
        ),
        .executable(
            name: "AulaDriverApp",
            targets: ["AulaDriverApp"]
        ),
        .executable(
            name: "aula-test-runner",
            targets: ["aula-test-runner"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AulaKit",
            dependencies: [],
            path: "Sources/AulaKit"
        ),
        .executableTarget(
            name: "aula-cli",
            dependencies: ["AulaKit"],
            path: "Sources/aula-cli"
        ),
        .executableTarget(
            name: "AulaDriverApp",
            dependencies: ["AulaKit"],
            path: "Sources/AulaDriverApp"
        ),
        .executableTarget(
            name: "aula-test-runner",
            dependencies: ["AulaKit"],
            path: "Tests/AulaKitTests"
        )
    ]
)
