# Twilio Voice SwiftUI Quickstart

A SwiftUI port of the Voice iOS quickstart. Demonstrates outgoing and incoming calls with CallKit and PushKit, using an `ObservableObject` to drive SwiftUI views from the Twilio Voice SDK.

## Features

- Dial pad and client-identity text field for outgoing calls
- In-call controls: mute, hold, speaker, call duration, quality warnings
- Incoming call UI with accept/decline, integrated with CallKit
- VoIP push registration via PushKit

## Structure

| File | Role |
| --- | --- |
| `SwiftUIVoiceQuickstartApp.swift` | App entry point, injects `CallManager` into the environment |
| `ContentView.swift` | Switches between `DialerView`, `IncomingCallView`, and `InCallView` based on call state |
| `CallManager.swift` | `ObservableObject` wrapping the Twilio Voice SDK; also acts as the `CallDelegate` / `NotificationDelegate` |
| `CallKitManager.swift` | CallKit provider and transaction handling |
| `PushKitManager.swift` | VoIP push registration and forwarding |
| `DialerView.swift` / `InCallView.swift` / `IncomingCallView.swift` | SwiftUI screens |

## Setup

See the top-level [README](../README.md) for the full quickstart setup (TwilioVoice SPM, access token, TwiML app, VoIP push credential). Once you have an access token, paste it into `accessToken` at the top of `CallManager.swift`, then build and run the `SwiftUIVoiceQuickstart` scheme.

## Screenshots

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-ios/raw/master/SwiftUIVoiceQuickstart/screenshots/dial-view.png"/></kbd> <kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-ios/raw/master/SwiftUIVoiceQuickstart/screenshots/call-view.png"/></kbd> <kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-ios/raw/master/SwiftUIVoiceQuickstart/screenshots/incoming-call-view.png"/></kbd>
