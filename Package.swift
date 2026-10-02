// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KNotes",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "KNotes", targets: ["KNotes"])
    ],
    targets: [
        .executableTarget(
            name: "KNotes",
            path: "Sources/KNotes"
        )
    ]
)
