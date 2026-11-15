// swift-tools-version: 5.9
import PackageDescription
import AppleProductTypes

let package = Package(
    name: "MirrorLink iPad",
    platforms: [.iOS("16.0")],
    products: [
        .iOSApplication(
            name: "MirrorLink iPad",
            targets: ["AppModule"],
            bundleIdentifier: "com.sedkar.mirrorlink.playground",
            displayVersion: "0.1",
            bundleVersion: "1",
            appIcon: .placeholder(icon: .tv),
            accentColor: .presetColor(.blue),
            supportedDeviceFamilies: [.pad],
            supportedInterfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight],
            capabilities: [
                .localNetwork(purposeString: "Samsung TV ile yerel ag baglantisini test etmek icin izin gerekir.", bonjourServiceTypes: []),
                .outgoingNetworkConnections()
            ],
            additionalInfoPlistContentFilePath: "AppInfo.plist"
        )
    ],
    targets: [
        .executableTarget(name: "AppModule", path: "AppModule")
    ]
)
