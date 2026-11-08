// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppMusicRPS",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AppMusicRPS",
            path: "AppMusicRPS",
            exclude: ["Resources", "Info.plist"],
            resources: [
                .copy("Resources/discord-rpc")
            ]
        )
    ]
)
