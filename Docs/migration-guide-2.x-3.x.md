## 2.x to 3.x Migration Guide
This section describes API or behavioral changes when upgrading from Voice iOS 2.x to Voice iOS 3.x. Each section provides code snippets to assist in transitioning to the new API.

1. [Making a Call](#making-a-call)
2. [TVOCallInvite Changes](#tvocallinvite-changes)
3. [Specifying a Media Region](#specifying-a-media-region)
4. [TVOConnectOptions & TVOAcceptOptions](#tvoconnectoptions-and-tvoacceptoptions)
5. [Media Establishment & Connectivity](#media-establishment-and-connectivity)
6. [CallKit](#callkit)
7. [Microphone Permission](#microphone-permission)

#### <a name="making-a-call"></a>Making a Call
In Voice iOS 3.x, the API to make a call has changed from `[TwilioVoice call:params:delegate:]` to `[TwilioVoice connectWithAccessToken:delegate]` or `[TwilioVoice connectWithOptions:delegate:]`.

```.swift
call = TwilioVoice.connect(with: connectOptions, delegate: self)
```

#### <a name="tvocallinvite-changes"></a>TVOCallInvite Changes
In Voice iOS 3.x, the `notificationError:` delegate method is removed from the `TVONotificationDelegate` protocol and the `[TwilioVoice handleNotification:]` method no longer raises errors via this method if an invalid notification is provided, instead a `BOOL` value is returned when `[TwilioVoice handleNotification:]` is called. The returned value is `YES` when the provided data resulted in a `TVOCallInvite` or `TVOCancelledCallInvite` received in the `TVONotificationDelegate` methods. If `NO` is returned it means the data provided was not a Twilio Voice push notification.

```.swift
func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, forType type: PKPushType) {
    if (!TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)) {
        // The push notification was not a Twilio Voice push notification.
    }
}

// MARK: TVONotificationDelegate
func callInviteReceived(_ callInvite: TVOCallInvite) {
    // Show notification to answer or reject call
}

func cancelledCallInviteReceived(_ cancelledCallInvite: TVOCancelledCallInvite) {
    // Hide notification
}
```

The `TVOCallInvite` has an `accept()` and `reject()` method. `TVOCallInviteState` has been removed from the `TVOCallInvite` in favor of distinguishing between call invites and call invite cancellations with discrete stateless objects. While the `TVOCancelledCallInvite` simply provides the `to`, `from`, and `callSid` fields also available in the `TVOCallInvite`. The property `callSid` can be used to associate a `TVOCallInvite` with a `TVOCancelledCallInvite`.

In Voice iOS 2.x passing a `cancel` notification into `[TwilioVoice handleNotification:delegate:]` would not raise a callback in the following two cases:
- This callee accepted the call
- This callee rejected the call

However, in Voice iOS 3.x passing a `cancel` notification payload into `[TwilioVoice handleNotification:delegate:]` will always result in a callback. A callback is raised whenever a valid notification is provided to `[TwilioVoice handleNotification:delegate:]`.

Note that Twilio will send a `cancel` notification to every registered device of the identity that accepts or rejects a call, even the device that accepted or rejected the call.

#### <a name="specifying-a-media-region"></a>Specifying a media region
Previously, a media region could be specified via `[TwilioVoice setRegion:]`. Now this configuration can be provided as part of `TVOConnectOptions` or `TVOAcceptOptions` as shown below:

```.swift
let connectOptions: TVOConnectOptions = TVOConnectOptions(accessToken: accessToken) { (builder) in
    builder.region = region
}

let acceptOptions: TVOAcceptOptions = TVOAcceptOptions(callInvite: callInvite!) { (builder) in
    builder.region = region
}
```

#### <a name="tvoconnectoptions-and-tvoacceptoptions"></a> TVOConnectOptions & TVOAcceptOptions
To support configurability upon making or accepting a call, new classes have been added. Create a `TVOConnectOptions` object and make configurations via the `TVOConnectOptionsBuilder` in the `block`. Once `TVOConnectOptions` is created it can be provided when connecting a Call as shown below:

```.swift
let options: TVOConnectOptions = TVOConnectOptions(accessToken: accessToken) { (builder) in
    builder.params = params
}

call = TwilioVoice.connect(with: options, delegate: self)
```

A `TVOCallInvite` can also be accepted using `TVOAcceptOptions` as shown below:

```.swift
let options: TVOAcceptOptions = TVOAcceptOptions(callInvite: callInvite!) { (builder) in
    builder.uuid = callInvite.uuid
}

call = callInvite.accept(with: options, delegate: self)
```

#### <a name="media-establishment-and-connectivity"></a>Media Establishment & Connectivity
The Voice iOS 3.x SDK uses WebRTC. The exchange of real-time media requires the use of Interactive Connectivity Establishment(ICE) to establish a media connection between the client and the media server. In some network environments where network access is restricted it may be necessary to provide ICE servers to establish a media connection. We reccomend using the [Network Traversal Service (NTS)](https://www.twilio.com/stun-turn) to obtain ICE servers. ICE servers can be provided when making or accepting a call by passing them into `TVOConnectOptions` or `TVOAcceptOptions` in the following way:

```.swift
var iceServers: Array<TVOIceServer> = Array()
let iceServer1: TVOIceServer = TVOIceServer(urlString: "stun:global.stun.twilio.com:3478?transport=udp",
                                            username: "",
                                            password: "")
iceServers.append(iceServer1)

let iceServer2: TVOIceServer = TVOIceServer(urlString: "turn:global.turn.twilio.com:3478?transport=udp",
                                            username: "TURN_USERNAME",
                                            password: "TURN_PASSWORD")
iceServers.append(iceServer2)

let iceOptions: TVOIceOptions = TVOIceOptions { (builder) in
    builder.servers = iceServers
}

// Specify ICE options in the builder
let connectOptions: TVOConnectOptions = TVOConnectOptions(accessToken: accessToken) { (builder) in
    builder.iceOptions = iceOptions
}

let acceptOptions: TVOAcceptOptions = TVOAcceptOptions(callInvite: callInvite!) { (builder) in
    builder.iceOptions = iceOptions
}
```

#### <a name="callkit"></a>CallKit
The Voice iOS 3.x SDK deprecates the `CallKitIntegration` category from `TwilioVoice` in favor of a new property called `TVODefaultAudioDevice.enabled`. This property provides developers with a mechanism to enable or disable the activation of the audio device prior to connecting to a Call or to stop or start the audio device while you are already connected to a Call. A Call can now be connected without activating the audio device by setting `TVODefaultAudioDevice.enabled` to `NO` and can be enabled during the lifecycle of the Call by setting `TVODefaultAudioDevice.enabled` to `YES`. The default value is `YES`. This API change was made to ensure full compatibility with CallKit as well as supporting other use cases where developers may need to disable the audio device during a call.

An example of managing the `TVODefaultAudioDevice` while connecting a CallKit Call:

```.swift
var audioDevice: TVODefaultAudioDevice = TVODefaultAudioDevice()

func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    audioDevice.isEnabled = false
    audioDevice.block();

    self.performVoiceCall(uuid: action.callUUID, client: "") { (success) in
        if (success) {
            provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
            action.fulfill()
        } else {
            action.fail()
        }
    }
}

func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    audioDevice.isEnabled = true
}

func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    audioDevice.isEnabled = false
    audioDevice.block();

    self.performAnswerVoiceCall(uuid: action.callUUID) { (success) in
        if (success) {
            action.fulfill()
        } else {
            action.fail()
        }
    }

    action.fulfill()
}

func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    // Disconnect or reject the call

    audioDevice.isEnabled = true
    action.fulfill()
}
```

See [CallKit Example](https://github.com/twilio/voice-quickstart-swift/blob/3.x/SwiftVoiceQuickstart/ViewController.swift) for the complete implementation.

#### <a name="microphone-permission"></a>Microphone Permission
Unlike Voice iOS 2.x SDKs where microphone permission is not optional in Voice 3.x SDKs, the call will connect even when the microphone permission is denied or disabled by the user, and the SDK will play the remote audio. To ensure the microphone permission is enabled prior to making or accepting a call you can add the following to request the permission beforehand:

```.swift
func makeCall() {
    // User's microphone option
    let microphoneEnabled: Bool = true
    
    if (microphoneEnabled) {
        self.checkRecordPermission { (permissionGranted) in
            if (!permissionGranted) {
                // The user might want to revisit the Privacy settings.
            } else {
                // Permission granted. Continue to make call.
            }
        }
    } else {
        // Continue to make call without microphone.
    }
}

func checkRecordPermission(completion: @escaping (_ permissionGranted: Bool) -> Void) {
    let permissionStatus: AVAudioSessionRecordPermission = AVAudioSession.sharedInstance().recordPermission()
    
    switch permissionStatus {
    case AVAudioSessionRecordPermission.granted:
        // Record permission already granted.
        completion(true)
        break
    case AVAudioSessionRecordPermission.denied:
        // Record permission denied.
        completion(false)
        break
    case AVAudioSessionRecordPermission.undetermined:
        // Requesting record permission.
        // Optional: pop up app dialog to let the users know if they want to request.
        AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
            completion(granted)
        })
        break
    default:
        completion(false)
        break
    }
}
```

