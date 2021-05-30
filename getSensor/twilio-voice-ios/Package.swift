// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "TwilioVoice",
    platforms: [
        .iOS(.v11)
    ],
    products: [
        .library(
            name: "TwilioVoice",
            targets: ["TwilioVoice"]),
    ],
    targets: [
        .binaryTarget(
            name: "TwilioVoice",
            url: "https://github.com/twilio/twilio-voice-ios/releases/download/6.3.0/TwilioVoice.xcframework.zip",
            checksum: "a3dbabd3ba4755a8a65faf7b2b59601b42ecaa82779e9738added7879511a392"
        )
    ]
)
