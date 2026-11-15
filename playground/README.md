# MirrorLink for Swift Playground on iPad

1. On iPad download **dist/MirrorLink-iPad.zip** from the repository.
2. In the Files app tap the ZIP to extract the `MirrorLink-iPad.swiftpm` app playground.
3. With Swift Playground installed, open the `.swiftpm` package from the Files app or Swift Playground > Recents > Browse.
4. Tap Run. Allow local network access when asked.
5. On the Samsung TV open Menu > Network > Network Status > IP Settings, and note its IP (e.g. 192.168.1.25).
6. Make sure the iPad and TV are on the same Wi-Fi network. Enter the IP and tap the test button.
7. Copy the result for troubleshooting.

This is **not** live screen mirroring. It only probes candidate DLNA/UPnP endpoints and optionally sends a read-only SOAP GetTransportInfo request if AVTransport is advertised. It does not install an app on the TV or change any TV settings.

Some Samsung TV models only advertise a DLNA MediaServer and may have no MediaRenderer (AVTransport), so this diagnostic may legitimately report that no service was found.

The app targets the iPad only. It uses local HTTP to talk with the old DLNA/UPnP service. Local network access permission is requested; there is no cloud transmission of the TV IP. The source bundle is in `playground/MirrorLink-iPad.swiftpm`.

The package has not been verified by running on the user's actual iPad. It may require adjustments based on Swift Playground and iPadOS versions.
