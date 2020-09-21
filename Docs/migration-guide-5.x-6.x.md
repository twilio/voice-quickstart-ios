## 5.x to 6.x Migration Guide

- The Voice SDK has been updated for better Swift interoperability. The `TVO` class prefix has been removed from all Twilio Voice types.
 
```swift
    let connectOptions = ConnectOptions(accessToken: accessToken) { builder in
        // build connect options using builder
    }
    let call = TwilioVoice.connect(options: connectOptions, delegate: self)
```
 
- This release has improved API for CallKit integration. In order to use CallKit with SDK, you must set `ConnectOptions.uuid` or `AcceptOptions.uuid` while making or answering a Call. When `ConnectOptions.uuid` or `AcceptOptions.uuid` is set, it is your responsibility to enable and disable the audio device. You should enable the audio device in `[CXProviderDelegate provider:didActivateAudioSession:]`, and disable the audio device in `[CXProviderDelegate provider:didDeactivateAudioSession:]`.

Passing a uuid to make a Call with CallKit code snippets -

```swift
    let uuid = UUID()
    
    let connectOptions = ConnectOptions(accessToken: accessToken) { builder in
        builder.uuid = uuid
    }

    let call = TwilioVoice.connect(options: connectOptions, delegate: self)
```


Passing a uuid to answer an incoming Call with CallKit code snippets -

```swift
    let acceptOptions = AcceptOptions(callInvite: callInvite) { builder in
         builder.uuid = callInvite.uuid
    }
        
    let call = callInvite.accept(options: acceptOptions, delegate: self)
```

`ProviderDelegate` implementation code snippets -

```swift
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        audioDevice.isEnabled = true
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        audioDevice.isEnabled = false
    }
    
    func providerDidReset(_ provider: CXProvider) {
        audioDevice.isEnabled = false
    }
```

Please note, if you are not using CallKit in your app, you must not set `ConnectOptions.uuid` or `AcceptOptions.uuid` while making or answering a call. The Voice SDK will enable the audio device for you when the `uuid` is `nil`. 

- The `[TwilioVoice registerWithAccessToken:deviceTokenData:completion:]` and the `[TwilioVoice unregisterWithAccessToken:deviceTokenData:completion:]` have been renamed to replace the `[TwilioVoice registerWithAccessToken:deviceToken:completion:]` and the `[TwilioVoice unregisterWithAccessToken:deviceToken:completion:]` methods and now take the `NSData` type device token as parameter.

- The `uuid` property of `TVOCall` is now optional.

- In this release, `[TVOCallDelegate callDidConnect:]` is raised when both the ICE connection state is connected and DTLS negotiation has completed. There is no change in behavior however the SDK can detect DTLS failures and raise `kTVOMediaDtlsTransportFailedErrorCode` if they occur.

| Error Codes | ErrorCode  | Error Message |
| ------------| -----------| ------------- |
| 53407 | TVOMediaDtlsTransportFailedErrorCode | Media connection failed due to DTLS handshake failure |