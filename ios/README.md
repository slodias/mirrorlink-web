# MirrorLink iOS — Stage 1 (Samsung 2014 DLNA inspection)

Native SwiftUI proof of concept. **Not a screen-mirroring app yet.**

What works in code:
- User enters the Samsung TV's private IPv4 address from Network Status.
- App probes a limited set of common HTTP UPnP/DLNA device-description endpoints (not guaranteed on UE40H6470).
- XML parser lists services and reports whether an AVTransport control URL exists.
- If AVTransport is present, the app can send read-only `GetTransportInfo` SOAP request.
- No multicast/SSDP discovery in this build; enabling it for iOS normally requires Apple's multicast entitlement.
- No ReplayKit Broadcast Upload Extension, video encoding, media server, or actual screen mirroring in this version.

## Build on GitHub without a personal Mac

The workflow `.github/workflows/ios-build.yml` builds for **iOS Simulator only**, without signing. It verifies source compilation but the artifact cannot be installed on a real iPhone.

To install on a physical iPhone you need Apple signing / provisioning and a macOS Xcode environment (which can be a hosted macOS runner configured securely). App Store/TestFlight distribution requires Apple Developer Program enrollment. A GitHub build alone is not an installable app.

## Privacy and security

Use only the local Wi-Fi address of a TV you control. Network requests stay local. Diagnostics may contain local IPs and service descriptions; avoid posting them publicly. Plain HTTP is used only to communicate with legacy UPnP devices on trusted local networks; do not expose sensitive content.

## Limitations

MediaServer browsing and AVTransport control are different DLNA roles. Finding a DLNA MediaServer does **not** prove the TV will accept a pushed live video stream. A ReplayKit capture pipeline alone cannot push video to a device without a compatible receiver, a supported media format, and a server/discovery protocol.

The previous browser prototype is independent and remains at the repository root.
