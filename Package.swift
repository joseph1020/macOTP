// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "macotp",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "MacOTPKit", targets: ["MacOTPKit"]),
        .executable(name: "macotp", targets: ["macotp"])
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite3",
            pkgConfig: "sqlite3"
        ),
        .target(
            name: "MacOTPKit",
            dependencies: ["CSQLite3"],
            resources: [
                .process("Resources/otp_keywords.json")
            ]
        ),
        .executableTarget(
            name: "macotp",
            dependencies: ["MacOTPKit"]
        ),
        .executableTarget(
            name: "macotp-selftest",
            dependencies: ["MacOTPKit"]
        ),
        .testTarget(
            name: "MacOTPKitTests",
            dependencies: ["MacOTPKit"]
        )
    ]
)
