# LiveCommunicationKit Voice Quickstart

This example shows how to integrate the Twilio Voice iOS SDK with Apple's [LiveCommunicationKit](https://developer.apple.com/documentation/livecommunicationkit) framework instead of CallKit. The two frameworks fill the same role — surfacing system-level call UI for VoIP apps — but LiveCommunicationKit (introduced in iOS 17.4) is the modern replacement and is required if you want your app to qualify as the system's default calling app.

The Twilio Voice integration (PushKit, `TwilioVoiceSDK.handleNotification`, `CallInvite`, `Call`, `CallDelegate`, `NotificationDelegate`, `DefaultAudioDevice`) is identical to the [SwiftVoiceQuickstart](../SwiftVoiceQuickstart) example. Only the system call-UI layer differs. Diff the two `ViewController.swift` files side-by-side to see exactly what changes.

## Requirements

- iOS 17.4+ deployment target (LiveCommunicationKit minimum)
- Xcode 15.3+
- A Twilio account with Programmable Voice configured (TwiML application, access token, VoIP push credential). See the [top-level README](../README.md) for setup instructions.

## CallKit → LiveCommunicationKit mapping

| CallKit | LiveCommunicationKit |
| --- | --- |
| `CXProvider` + `CXCallController` | `ConversationManager` |
| `CXProviderConfiguration` | `ConversationManager.Configuration` |
| `CXProviderDelegate` | `ConversationManagerDelegate` |
| `CXHandle` | `Handle` |
| `CXCallUpdate` | `Conversation.Update` |
| `CXStartCallAction` | `StartConversationAction` |
| `CXAnswerCallAction` | `JoinConversationAction` |
| `CXEndCallAction` | `EndConversationAction` |
| `CXSetMutedCallAction` | `MuteConversationAction` |
| `CXSetHeldCallAction` | `PauseConversationAction` |
| `CXPlayDTMFCallAction` | `PlayToneAction` |
| `callController.request(transaction)` | `try await manager.perform([action])` |
| `provider.reportNewIncomingCall(with:update:)` | `try await manager.reportNewIncomingConversation(uuid:update:)` |
| `provider.reportOutgoingCall(...)` / `reportCall(with:endedAt:reason:)` | `manager.reportConversationEvent(_:for:)` |
| Per-action delegate methods (`provider(_:perform: CXStartCallAction)` etc.) | Single `conversationManager(_:perform: ConversationAction)` callback — switch on the concrete action type |

## Setup

1. Follow steps 1–6 of the [top-level quickstart](../README.md) to set up a TwiML application and VoIP push credential, and to deploy the Twilio Serverless token-vending function.
2. Open `VoiceQuickstart.xcworkspace` and select the **LiveCommunicationKitExample** scheme.
3. In `LiveCommunicationKitExample/ViewController.swift`, replace `PASTE_YOUR_ACCESS_TOKEN_HERE` with a valid access token (or wire it up to fetch from your token endpoint).
4. Set your Apple development team on the target's **Signing & Capabilities** tab.
5. Build and run on a physical iPhone running iOS 17.4 or later. PushKit and LiveCommunicationKit both require a real device.

## Entitlements

This example uses only the standard `aps-environment` entitlement plus the `audio` and `voip` background modes. The `com.apple.developer.live-communication` entitlement is **not** required for the in-app VoIP UI use case shown here — it is only needed to register your app as the system's default dialer / cellular-fallback path (`TelephonyConversationManager`, `StartCellularConversationAction`), which this example does not demonstrate.

## Notes

- LiveCommunicationKit's `perform([action])` is `async throws`. UISwitch and button handlers wrap the call in a `Task { ... }` rather than the closure-based `callController.request(transaction)` pattern.
- LiveCommunicationKit dispatches all action callbacks through a single `conversationManager(_:perform:)` method. The example switches on the concrete subclass (`StartConversationAction`, `JoinConversationAction`, …) to fan out to per-action handlers.
- `Conversation` objects are looked up on `conversationManager.conversations` by UUID when reporting outgoing-call lifecycle events (`conversationStartedConnecting`, `conversationConnected`, `conversationEnded`).
