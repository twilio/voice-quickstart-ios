# Twilio Voice Swift Quickstart for iOS

> This is a beta release of the Programmable Voice 3.X SDK for iOS. This major version now uses WebRTC. APIs are unlikely to change. We recommend you look at known issues provided in the [changelog](https://www.twilio.com/docs/voice/voip-sdk/ios/3x-changelog).
> To use a generally available version of the Programmable Voice SDKs for iOS please see the [master](https://github.com/twilio/video-quickstart-swift/tree/master) branch based on the 2.X APIs.

## Get started with Voice on iOS:
* [Quickstart](#quickstart) - Run the quickstart app
* [New Features](#new-features) - New features in 3.X
* [Migration Guide](#migration-guide) - Migrating from 2.X to 3.X
* [Access Tokens](#access-tokens) - Using access tokens
* [Managing Audio Interruptions](#managing-audio-interruptions) - Managing audio interruptions
* [Managing Push Credentials](#managing-push-credentials) - Managing push credentials
* [More Documentation](#more-documentation) - More documentation related to the Voice iOS SDK
* [Issues and Support](#issues-and-support) - Filing issues and general support

## Quickstart
To get started with the quickstart application follow these steps. Steps 1-6 will enable the application to make a call. The remaining steps 7-10 will enable the application to receive incoming calls in the form of push notifications using Apple’s VoIP Service.

1. [Install the TwilioVoice framework](#bullet1)
2. [Create a Voice API key](#bullet2)
3. [Configure a server to generate an access token to be used in the app](#bullet3)
4. [Create a TwiML application](#bullet4)
5. [Configure your application server](#bullet5)
6. [Run the app](#bullet6)
7. [Create a VoIP Service Certificate](#bullet7)
8. [Create a Push Credential with your VoIP Service Certificate](#bullet8)
9. [Configure Xcode project settings for VoIP push notifications](#bullet9)
10. [Receive an incoming call](#bullet10)
11. [Make client to client call](#bullet11)
12. [Make client to PSTN call](#bullet12)

### <a name="bullet1"></a>1. Install the TwilioVoice framework

**Carthage**

Add the following line to your Cartfile

```
github "twilio/twilio-voice-ios"
```

Then run `carthage bootstrap` (or `carthage update` if you are updating your SDKs)

On your application targets’ “Build Phases” settings tab, click the “+” icon and choose “New Run Script Phase”. Create a Run Script in which you specify your shell (ex: `/bin/sh`), add the following contents to the script area below the shell:

```
/usr/local/bin/carthage copy-frameworks
```

Add the paths to the frameworks you want to use under “Input Files”, e.g.:

```
$(SRCROOT)/Carthage/Build/iOS/TwilioVoice.framework
```

**Cocoapods**

Under the quickstart path, run `pod install` and let the Cocoapods library create the workspace for you. Also please make sure to use **Cocoapods v1.0 and later**.
Once Cocoapods finishes installing, open the `SwiftVoiceQuickstart.xcworkspace` and you will find a basic Swift quickstart project and a CallKit quickstart project.

Note: You may need to update the [CocoaPods Master Spec Repo](https://github.com/CocoaPods/Specs) by running `pod repo update master` in order to fetch the latest specs for TwilioVoice.

### <a name="bullet2"></a>2. Create a Voice API key
Go to the [Voice API Keys](https://www.twilio.com/console/voice/settings/api-keys) page and create a new API key:

<kbd><img src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/create-api-key.png"/></kbd>

**Save the generated `API_KEY` and `API_KEY_SECRET` in your notepad**. You will need them in the next step.

### <a name="bullet3"></a>3. Configure a server to generate an access token to be used in the app

Download one of the starter projects for the server.

* [voice-quickstart-server-java](https://github.com/twilio/voice-quickstart-server-java)
* [voice-quickstart-server-node](https://github.com/twilio/voice-quickstart-server-node)
* [voice-quickstart-server-php](https://github.com/twilio/voice-quickstart-server-php)
* [voice-quickstart-server-python](https://github.com/twilio/voice-quickstart-server-python)

Follow the instructions in the server's README to get the application server up and running locally and accessible via the public Internet. For now just replace the **Twilio Account SID** that you can obtain from the [console](https://www.twilio.com/console), and the `API_KEY` and `API_SECRET` you obtained in the previous step.
    
    ACCOUNT_SID = 'AC***'
    API_KEY = 'SK***'
    API_KEY_SECRET = '***'

### <a name="bullet4"></a>4. Create a TwiML application
Next, we need to create a TwiML application. A TwiML application identifies a public URL for retrieving [TwiML call control instructions](https://www.twilio.com/docs/api/twiml). When your iOS app makes a call to the Twilio cloud, Twilio will make a webhook request to this URL, your application server will respond with generated TwiML, and Twilio will execute the instructions you’ve provided.
To create a TwiML application, go to the [TwiML app page](https://www.twilio.com/console/voice/dev-tools/twiml-apps). Create a new TwiML application, and use the public URL of your application server’s `/makeCall` endpoint as the Voice Request URL (If your app server is written in PHP, then you need `.php` extension at the end).

<kbd><img src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/create-twiml-app.png"/></kbd>

As you can see we’ve used our [ngrok](https://ngrok.com/) public address in the Request URL field above.
Save your TwiML Application configuration, and grab the **TwiML Application SID** (a long identifier beginning with the characters `AP`).

### <a name="bullet5"></a>5. Configure your application server
Let's put the remaining `APP_SID` configuration info into your server code. 

    ACCOUNT_SID = 'AC***'
    API_KEY = 'SK***'
    API_KEY_SECRET = '***'
    APP_SID = 'AP***'

Once you’ve done that, restart the server so it uses the new configuration info. Now it's time to test.

Open up a browser and visit the URL for your application server's **Access Token endpoint**: `https://{YOUR_SERVER_URL}/accessToken` (If your app server is written in PHP, then you need `.php` extension at the end). If everything is configured correctly, you should see a long string of letters and numbers, which is a Twilio Access Token. Your iOS app will use a token like this to connect to Twilio.

### <a name="bullet6"></a>6. Run the app
Now let’s go back to the `SwiftVoiceQuickstart.xcworkspace`. Update the placeholder of `baseURLString` with your ngrok public URL

```swift
import UIKit
import AVFoundation
import PushKit
import TwilioVoice

let baseURLString = "https://3b57e324.ngrok.io"
let accessTokenEndpoint = "/accessToken"
let identity = "alice"
let twimlParamTo = "to"

class ViewController: UIViewController, PKPushRegistryDelegate, TVONotificationDelegate, TVOCallDelegate, AVAudioPlayerDelegate, UITextFieldDelegate {
```

Build and run the app

<kbd><img width="500px" src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/build-and-run.png"/></kbd>

Leave the text field empty and press the call button to start a call. You will hear the congratulatory message. Support for dialing another client or number is described in steps 11 and 12. Tap "Hang Up" to disconnect.

<kbd><img width="500px" src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/hang-up.png"/></kbd>

### <a name="bullet7"></a>7. Create VoIP Service Certificate
The Programmable Voice SDK uses Apple’s VoIP Services to let your application know when it is receiving an incoming call. If you want your users to receive incoming calls, you’ll need to enable VoIP Services in your application and generate a VoIP Services Certificate.

Go to [Apple Developer portal](https://developer.apple.com/) and you’ll need to do the following:
- An Apple Developer membership to be able to create the certificate.
- Make sure your App ID has the “Push Notifications” service enabled.
- Create a corresponding Provisioning Profile for your app ID.
- Create an [Apple VoIP Services Certificate](https://developer.apple.com/library/prerelease/content/documentation/Performance/Conceptual/EnergyGuide-iOS/OptimizeVoIP.html#//apple_ref/doc/uid/TP40015243-CH30-SW1) for this app by navigating to Certificates --> Production and clicking the `+` on the top right to add the new certificate.

<kbd><img src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/create-voip-service-certificate.png"/></kbd>

### <a name="bullet8"></a>8. Create a Push Credential with your VoIP Service Certificate
Once you have generated the VoIP Services Certificate using Keychain Access, you will need to upload it to Twilio so that Twilio can send push notifications to your app on your behalf.

Export your VoIP Service Certificate as a .p12 file from Keychain Access, then extract the certificate and private key from the .p12 file using the `openssl` command. If .p12 is not an option for exporting, type `voip` into the search bar of Keychain Access and make sure you select both items when exporting the certificate.

    $> openssl pkcs12 -in PATH_TO_YOUR_P12 -nocerts -out key.pem
    $> openssl rsa -in key.pem -out key.pem
    $> openssl pkcs12 -in PATH_TO_YOUR_P12 -clcerts -nokeys -out cert.pem

Go to the [Push Credentials page](https://www.twilio.com/console/voice/sdks/credentials) and create a new Push Credential. Paste the certificate and private key extracted from your certificate. You must paste the keys in as plaintext:

* For the `cert.pem` you should paste everything from `-----BEGIN CERTIFICATE-----` to `-----END CERTIFICATE-----`. 
* For the `key.pem` you should paste everything from `-----BEGIN RSA PRIVATE KEY-----` to `-----END RSA PRIVATE KEY-----`.

**Remember to check the “Sandbox” option**. This is important. The VoIP Service Certificate you generated can be used both in production and with Apple's sandbox infrastructure. Checking this box tells Twilio to send your pushes to the Apple sandbox infrastructure which is appropriate with your development provisioning profile.

Once the app is ready for store submission, update the plist with “APS Environment: production” and create another Push Credential with the same VoIP Certificate but without checking the sandbox option.

<kbd><img src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/add-push-credential.png"/></kbd>

Now let's go back to your server code and update the Push Credential SID. The Push Credential SID will now be embedded in your access token.

    PUSH_CREDENTIAL_SID = 'CR***'

### <a name="bullet9"></a>9. Configure Xcode project settings for push notifications
On the project’s Capabilities tab, enable “**Push Notifications**”.
In Xcode 8 or earlier, enable both “**Voice over IP**” and “**Audio, AirPlay and Picture in Picture**” capabilities in the Background Modes

<kbd><img src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/xcode-project-capabilities.png"/></kbd>

In Xcode 9+, make sure that the “**Audio, AirPlay and Picture in Picture**” capability is enabled and a "**UIBackgroundModes**" dictionary with "**audio**" and "**voip**" is in the app's plist.
```
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
  <string>voip</string>
</array>
```

### <a name="bullet10"></a>10. Receive an incoming call
You are now ready to receive incoming calls. Rebuild your app and hit your application server's **/placeCall** endpoint: `https://{YOUR_SERVER_URL}/placeCall` (If your app server is written in PHP, then you need `.php` extension at the end). This will trigger a Twilio REST API request that will make an inbound call to your mobile app. Once your app accepts the call, you should hear a congratulatory message.

<kbd><img width="500px" src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/incoming-call.png"/></kbd>

### <a name="bullet11"></a>11. Make client to client call
To make client to client calls, you need the application running on two devices. To run the application on an additional device, make sure you use a different identity in your access token when registering the new device. For example, change `kIdentity` to `bob` and run the application

```swift
let accessTokenEndpoint = "/accessToken"
let identity = "bob"
let twimlParamTo = "to"
```

Use the text field to specify the identity of the call receiver, then tap the “Call” button to make a call. The TwiML parameters used in `TwilioVoice.connect()` method should match the name used in the server.

<kbd><img width="500px" src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/client-to-client.png"/></kbd>

### <a name="bullet12"></a>12. Make client to PSTN call
A verified phone number is one that you can use as your Caller ID when making outbound calls with Twilio. This number has not been ported into Twilio and you do not pay Twilio for this phone number.

To make client to number calls, first get a valid Twilio number to your account via https://www.twilio.com/console/phone-numbers/verified. Update your server code and replace `CALLER_NUMBER` with the verified number. Restart the server so it uses the new value. Voice Request URL of your TwiML application should point to the public URL of your application server’s `/makeCall` endpoint.

<kbd><img width="500px" src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/client-to-pstn.png"/></kbd>

## Access Tokens

The access token generated by your server component is a [jwt](https://jwt.io) that contains a `grant` for Programmable Voice, an `identity` that you specify, and a `time-to-live` that sets the lifetime of the generated access token. The default `time-to-live` is 1 hour and is configurable up to 24 hours using the Twilio helper libraries.

### Uses

In the iOS SDK the access token is used for the following:

1. To make an outgoing call via `TwilioVoice.connect(...)`
2. To register or unregister for incoming notifications using VoIP Push Notifications via `TwilioVoice.registerWithAccessToken(...)` and `TwilioVoice.unregisterWithAccessToken(...)`. Once registered, incoming notifications are handled via a `TVOCallInvite` where you can choose to accept or reject the invite. When accepting the call an access token is not required. Internally the `TVOCallInvite` has its own access token that ensures it can connect to our infrastructure.

### Managing Expiry

As mentioned above, an access token will eventually expire. If an access token has expired, our infrastructure will return error `TVOErrorAccessTokenExpired`/`20104` via `TVOCallDelegate` or a completion error when registering.

There are number of techniques you can use to ensure that access token expiry is managed accordingly:

- Always fetch a new access token from your access token server before making an outbound call.
- Retain the access token until getting a `TVOErrorAccessTokenExpired`/`20104` error before fetching a new access token.
- Retain the access token along with the timestamp of when it was requested so you can verify ahead of time whether the token has already expired based on the `time-to-live` being used by your server.
- Prefetch the access token whenever the `UIApplication`, or `UIViewController` associated with an outgoing call is created.

## New Features
Voice iOS 3.X has a number of new features listed below:

1. [WebRTC](#webrtc)
2. [Custom Parameters](#custom-parameters)
3. [Call Ringing APIs](#call-ringing-apis)
4. [Media Stats](#media-stats)
5. [Audio Device APIs](#audio-device-apis)
    * [Default Audio Device](#default-audio-device)
    * [Custom Audio Device](#custom-audio-device)
6. [Preferred Audio Codec](#preferred-audio-codec)

#### <a name="webrtc"></a>WebRTC
The SDK is built using Chromium WebRTC for iOS. This ensures that over time developers will get the best real-time media streaming capabilities available for iOS. Additionally, upgrades to new versions of Chromium WebRTC will happen without changing the public API whenever possible.

#### <a name="custom-parameters"></a>Custom Parameters
Custom Parameters is now supported in `TVOCallInvite`. `TVOCallInvite.customParamaters` returns a `NSDictionary` of custom parameters sent from the caller side to the callee.

Pass custom parameters in TwiML:

```.xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
  <Dial callerId="client:alice">
    <Client>
      <Identity>bob</Identity>
      <Parameter name="caller_first_name" value="alice" />
      <Parameter name="caller_last_name" value="smith" />
    </Client>
  </Dial>
</Response>
```

`callInvite.customParameters` returns a dictionary of key-value pairs passed in the TwiML:

```.objc
{
  "caller_first_name" = "alice";
  "caller_last_name" = "smith";
}
```

#### <a name="call-ringing-apis"></a>Call Ringing APIs
Ringing is now provided as a call state. The delegate method `callDidStartRinging:` corresponding to this state transition is called once before the `callDidConnect:` method when the callee is being alerted of a Call. The behavior of this callback is determined by the `answerOnBridge` flag provided in the `Dial` verb of your TwiML application associated with this client. If the `answerOnBridge` flag is `false`, which is the default, the `callDidConnect:` callback will be called immediately after `callDidStartRinging:`. If the `answerOnBridge` flag is `true`, this will cause the `callDidConnect:` method being called only after the Call is answered. See [answerOnBridge](https://www.twilio.com/docs/voice/twiml/dial#answeronbridge) for more details on how to use it with the `Dial` TwiML verb. If the TwiML response contains a `Say` verb, then the `callDidConnect:` method will be called immediately after `callDidStartRinging:` is called, irrespective of the value of `answerOnBridge` being set to `true` or `false`.

These changes are added as follows:

```.objc
// TVOCall.h
typedef NS_ENUM(NSUInteger, TVOCallState) {
    TVOCallStateConnecting = 0, ///< The Call is connecting.
    TVOCallStateRinging,        ///< The Call is ringing.
    TVOCallStateConnected,      ///< The Call is connected.
    TVOCallStateDisconnected    ///< The Call is disconnected.
};

// TVOCallDelegate.h
@protocol TVOCallDelegate

@optional
- (void)callDidStartRinging:(nonnull TVOCall *)call;

@end
```

#### <a name="media-stats"></a>Media Stats
In Voice iOS 3.X SDK you can now access media stats in a Call using the `[TVOCall getStatsWithBlock:]` method.

```.swift
call.getStatsWith { (statsReports) in
    for report: TVOStatsReport in statsReports {
        let localAudioTracks: Array<TVOLocalAudioTrackStats> = report.localAudioTrackStats
        let localAudioTrackStats = localAudioTracks[0]
        let remoteAudioTracks: Array<TVORemoteAudioTrackStats> = report.remoteAudioTrackStats
        let remoteAudioTrackStats = remoteAudioTracks[0]

        print("Local Audio Track - audio level: \(localAudioTrackStats.audioLevel), packets sent: \(localAudioTrackStats.packetsSent)")
        print("Remote Audio Track - audio level: \(remoteAudioTrackStats.audioLevel), packets received: \(remoteAudioTrackStats.packetsReceived)")
    }
}
```

### <a name="audio-device-apis"></a>Audio Device APIs

#### <a name="default-audio-device"></a>Default Audio Device
In Voice iOS 3.X SDK, `TVODefaultAudioDevice` is used as the default device for rendering and capturing audio.
 An example of using `TVODefaultAudioDevice` to change the audio route from receiver to the speaker in a live call:
 
```.swift
let audioDevice: TVODefaultAudioDevice = TwilioVoice.audioDevice as! TVODefaultAudioDevice
audioDevice.block = {
    // We will execute `kDefaultAVAudioSessionConfigurationBlock` first.
    kDefaultAVAudioSessionConfigurationBlock()

    let session: AVAudioSession = AVAudioSession.sharedInstance()
    do {
        try session.overrideOutputAudioPort(.speaker)
    } catch _ {
        // Failed to change audio route from receiver to the speaker
    }
}

audioDevice.block();
```

#### <a name="custom-audio-device"></a>Custom Audio Device
The `TVOAudioDevice` protocol gives you the ability to replace `TVODefaultAudioDevice`. By implementing the `TVOAudioDevice` protocol, you can write your own audio capturer to feed audio samples to the Voice SDK and an audio renderer to receive the remote audio samples. For example, you could integrate with `ReplayKit2` and capture application audio for broadcast or play music using `AVAssetReader`.

Connecting to a Call using the `AVAudioSessionCategoryPlayback` category:

```.swift
let audioDevice: TVOAudioDevice = TVODefaultAudioDevice { (builder) in
    // Execute the `kDefaultAVAudioSessionConfigurationBlock` first.
    kDefaultAVAudioSessionConfigurationBlock();

    let session: AVAudioSession = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(AVAudioSessionCategoryPlayback, mode: AVAudioSessionModeVoiceChat, options: .allowBluetooth)
    } catch _ {
        // Failed to set AVAudioSession category
    }
}

TwilioVoice.audioDevice = audioDevice
call = TwilioVoice.connect(with: connectOptions, delegate: self)
```

### <a name="preferred-audio-codec"></a>Preferred Audio Codec
In Voice iOS 3.X, you can provide your preferred audio codec in the `TVOConnectOptions` and the `TVOAcceptOptions`.
The only audio codec supported by our mobile infrastructure is currently PCMU. Opus is not currently available on our mobile infrastructure. However it will become available in Q1 of 2019. At that point the default audio codec for all 3.X mobile clients will be Opus. To always use PCMU as the negotiated audio codec instead you can add it as the first codec in the `preferAudioCodecs` list.

```.swift
let connectOptions: TVOConnectOptions = TVOConnectOptions(accessToken: accessToken) { (builder) in
    builder.preferredAudioCodecs = [ TVOOpusCodec(), TVOPcmuCodec() ]
}
```

## Migration Guide
This section describes API or behavioral changes when upgrading from Voice iOS 2.X to Voice iOS 3.X. Each section provides code snippets to assist in transitioning to the new API.

1. [Making a Call](#making-a-call)
2. [TVOCallInvite Changes](#tvocallinvite-changes)
3. [Specifying a Media Region](#specifying-a-media-region)
4. [TVOConnectOptions & TVOAcceptOptions](#tvoconnectoptions-and-tvoacceptoptions)
5. [Media Establishment & Connectivity](#media-establishment-and-connectivity)
6. [CallKit](#callkit)
7. [Microphone Permission](#microphone-permission)

#### <a name="making-a-call"></a>Making a Call
In Voice iOS 3.X, the API to make a call has changed from `[TwilioVoice call:params:delegate:]` to `[TwilioVoice connectWithAccessToken:delegate]` or `[TwilioVoice connectWithOptions:delegate:]`.

```.swift
call = TwilioVoice.connect(with: connectOptions, delegate: self)
```

#### <a name="tvocallinvite-changes"></a>TVOCallInvite Changes
In Voice iOS 3.X, the `notificationError:` delegate method is removed from the `TVONotificationDelegate` protocol and the `[TwilioVoice handleNotification:]` method no longer raises errors via this method if an invalid notification is provided, instead a `BOOL` value is returned when `[TwilioVoice handleNotification:]` is called. The returned value is `YES` when the provided data resulted in a `TVOCallInvite` or `TVOCancelledCallInvite` received in the `TVONotificationDelegate` methods. If `NO` is returned it means the data provided was not a Twilio Voice push notification.

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

In Voice iOS 2.X passing a `cancel` notification into `[TwilioVoice handleNotification:delegate:]` would not raise a callback in the following two cases:
- This callee accepted the call
- This callee rejected the call

However, in Voice iOS 3.X passing a `cancel` notification payload into `[TwilioVoice handleNotification:delegate:]` will always result in a callback. A callback is raised whenever a valid notification is provided to `[TwilioVoice handleNotification:delegate:]`.

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
The Voice iOS 3.X SDK uses WebRTC. The exchange of real-time media requires the use of Interactive Connectivity Establishment(ICE) to establish a media connection between the client and the media server. In some network environments where network access is restricted it may be necessary to provide ICE servers to establish a media connection. We reccomend using the [Network Traversal Service (NTS)](https://www.twilio.com/stun-turn) to obtain ICE servers. ICE servers can be provided when making or accepting a call by passing them into `TVOConnectOptions` or `TVOAcceptOptions` in the following way:

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
The Voice iOS 3.X SDK deprecates the `CallKitIntegration` category from `TwilioVoice` in favor of a new property called `TVODefaultAudioDevice.enabled`. This property provides developers with a mechanism to enable or disable the activation of the audio device prior to connecting to a Call or to stop or start the audio device while you are already connected to a Call. A Call can now be connected without activating the audio device by setting `TVODefaultAudioDevice.enabled` to `NO` and can be enabled during the lifecycle of the Call by setting `TVODefaultAudioDevice.enabled` to `YES`. The default value is `YES`. This API change was made to ensure full compatibility with CallKit as well as supporting other use cases where developers may need to disable the audio device during a call.

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

See [CallKit Example](https://github.com/twilio/voice-quickstart-swift/blob/3.x/SwiftVoiceCallKitQuickstart/ViewController.swift) for the complete implementation.

#### <a name="microphone-permission"></a>Microphone Permission
Unlike Voice iOS 2.X SDKs where microphone permission is not optional in Voice 3.X SDKs, the call will connect even when the microphone permission is denied or disabled by the user, and the SDK will play the remote audio. To ensure the microphone permission is enabled prior to making or accepting a call you can add the following to request the permission beforehand:

```
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

## Managing Audio Interruptions
Different versions of iOS deal with **AVAudioSession** interruptions sightly differently. This section documents how the Programmable Voice iOS SDK manages audio interruptions and resumes call audio after the interruption ends. There are currently some cases that the SDK cannot resume call audio automatically because iOS does not provide the necessary notifications to indicate that the interruption has ended.

### How Programmable Voice iOS SDK handles audio interruption
- The `TVOCall` object registers itself as an observer of `AVAudioSessionInterruptionNotification` when it's created.
- When the notification is fired and the interruption type is `AVAudioSessionInterruptionTypeBegan`, the `TVOCall` object automatically disables both the local and remote audio tracks.
- When the SDK receives the notification with `AVAudioSessionInterruptionTypeEnded`, it re-enables the local and remote audio tracks and resumes the audio of active Calls.
  - We have noticed that on iOS 8 and 9, the interruption notification with `AVAudioSessionInterruptionTypeEnded` is not always fired therefore the SDK is not able to resume call audio automatically. This is a known issue and an alternative way is to use the `UIApplicationDidBecomeActiveNotification` and resume audio when the app is active again after the interruption.

### Notifications in different iOS versions
Below is a table listing the system notifications received with different steps to trigger audio interruptions and resume during an active Voice SDK call. (Assume the app is in an active Voice SDK call)

|Scenario|Notification of interruption-begins|Notification of interruption-ends|Call audio resumes?|Note|
|---|---|---|---|---|
|PSTN Interruption|
|A.<br>PSTN interruption<br>Accept the PSTN incoming call<br>Remote party of PSTN call hangs up|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|B.<br>PSTN interruption<br>Accept the PSTN incoming call<br>Local party of PSTN call hangs up|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|C.<br>PSTN interruption<br>Reject PSTN|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|D.<br>PSTN interruption<br>Ignore PSTN|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|E.<br>PSTN interruption<br>Remote party of PSTN call hangs up before local party can answer|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|Other Types of Audio Interruption<br>(YouTube app as example)|
|F.<br>Switch to YouTube app and play video<br>Stop the video<br>Switch back to Voice app|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:x: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:x: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|Interruption-ended notification is not fired on iOS 9.<br>Interruption-ended notification is not fired until few seconds after switching back to the Voice app on iOS 10/11.<br>The `AVAudioSessionInterruptionOptionShouldResume` flag is `false`.|
|G.<br>Switch to YouTube app and play video<br>Switch back to Voice app without stopping the video|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:x: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:x: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|Interruption-ended notification is not fired on iOS 9.<br>Interruption-ended notification is not fired until few seconds after switching back to the Voice app on iOS 10/11.<br>The `AVAudioSessionInterruptionOptionShouldResume` flag is `false`.|
|H.<br>Switch to YouTube app and play video<br>Double-press Home button and terminate YouTube app<br>Back to Voice app|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|Interruption-ended notification is not fired until the Voice app is back to the active state.<br>The `AVAudioSessionInterruptionOptionShouldResume` flag is `false`.|

### CallKit
On iOS 10 and later, CallKit (if integrated) takes care of the interruption by providing a set of delegate methods so that the application can respond with proper audio device handling and state transitioning in order to ensure call audio works after the interruption has ended.

#### Notifications & Callbacks during Interruption
By enabling the `supportsHolding` flag of the `CXCallUpdate` object when reporting a call to the CallKit framework, you will see the **“Hold & Accept”** option when there is another PSTN or CallKit-enabled call. By pressing the **“Hold & Accept”** option, a series of things and callbacks will happen:

1. The `provider:performSetHeldCallAction:` delegate method is called with `CXSetHeldCallAction.isOnHold = YES`. Put the Voice call on-hold here and fulfill the action.
2. The `AVAudioSessionInterruptionNotification` notification is fired to indicate the AVAudioSession interruption has started.
3. CallKit will deactivate the AVAudioSession of your app and fire the `provider:didDeactivateAudioSession:` callback.
4. When the interrupting call ends, instead of getting the `AVAudioSessionInterruptionNotification` notification, the system will notify that you can resume the call audio that was put on-hold when the interruption began by calling the `provider:performSetHeldCallAction:` method again. **Note** that this callback is not fired if the interrupting call is disconnected by the remote party.
5. The AVAudioSession of the app will be activated again and you should re-enable the audio device of the SDK `TwilioVoice.audioDevice.enabled = YES` in the `provider:didActivateAudioSession:` method.

|Scenario|Audio resumes after interrupion?|Note|
|---|---|---|
|A.<br>Hold & Accept<br>Hang up PSTN interruption on the local end|:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|B.<br>Hold & Accept<br>Remote party hangs up PSTN interruption|:x: iOS 10<br>:x: iOS 11|`provider:performSetHeldCallAction:` not called after the interruption ends.|
|C.<br>Hold & Accept<br>Switch back to the Voice Call on system UI|:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|D.<br>Reject|:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|No actual audio interruption happened since the interrupting call is not answered|
|E.<br>Ignore|:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|No actual audio interruption happened since the interrupting call is not answered|

In case 2, CallKit does not automatically resume call audio by calling `provider:performSetHeldCallAction:` method, but the system UI will show that the Voice call is still on-hold. You can resume the call using the **"Hold"** button, or use the `CXSetHeldCallAction` to lift the on-hold state programmatically. The app is also responsible of updating UI state to indicate the "hold" state of the call to avoid user confusion.

```.objc
// Resume call audio programmatically after interruption
CXSetHeldCallAction *setHeldCallAction = [[CXSetHeldCallAction alloc] initWithCallUUID:self.call.uuid onHold:holdSwitch.on];
CXTransaction *transaction = [[CXTransaction alloc] initWithAction:setHeldCallAction];
[self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
    if (error) {
        NSLog(@"Failed to submit set-call-held transaction request");
    } else {
        NSLog(@"Set-call-held transaction successfully done");
    }
}];
```

## Managing Push Credentials

A push credential is a record for a push notification channel, for iOS this push credential is a push notification channel record for APNS VoIP. Push credentials are managed in the console under [Mobile Push Credentials](https://www.twilio.com/console/voice/sdks/credentials).

Whenever a registration is performed via `TwilioVoice.registerWithAccessToken:deviceToken:completion` in the iOS SDK the `identity` and the `Push Credential SID` provided in the JWT based access token, along with the `device token` are used as a unique address to send APNS VoIP push notifications to this application instance whenever a call is made to reach that `identity`. Using `TwilioVoice.unregisterWithAccessToken:deviceToken:completion` removes the association for that `identity`.

### Updating a Push Credential

If you need to change or update your credentials provided by Apple you can do so by selecting the Push Credential in the [console](https://www.twilio.com/console/voice/sdks/credentials) and adding your new `certificate` and `private key` in the text box provided on the Push Credential page shown below:

<kbd><img height="667px" src="Images/update_push_credential.png"/></kbd>

### Deleting a Push Credential

We **do not recommend that you delete a Push Credential** unless the application that it was created for is no longer being used.

If **your APNS VoIP certificate is expiring soon or has expired you should not delete your Push Credential**, instead you should update the Push Credential by following the `Updating a Push Credential`  section.

When a Push Credential is deleted **any associated registrations made with this Push Credential will be deleted**. Future attempts to reach an `identity` that was registered using the Push Credential SID of this deleted push credential **will fail**.

If you are certain you want to delete a Push Credential you can click on `Delete this Credential` on the [console](https://www.twilio.com/console/voice/sdks/credentials) page of the selected Push Credential.

Please ensure that after deleting the Push Credential you remove or replace the Push Credential SID when generating new access tokens.

## More Documentation
You can find more documentation on getting started as well as our latest AppleDoc below:

* [Getting Started](https://www.twilio.com/docs/api/voice-sdk/ios/getting-started)
* [AppleDoc](https://media.twiliocdn.com/sdk/ios/voice/releases/3.0.0-beta7/docs)

## Twilio Helper Libraries
To learn more about how to use TwiML and the Programmable Voice Calls API, check out our TwiML quickstarts:

* [TwiML Quickstart for Python](https://www.twilio.com/docs/quickstart/python/twiml)
* [TwiML Quickstart for Ruby](https://www.twilio.com/docs/quickstart/ruby/twiml)
* [TwiML Quickstart for PHP](https://www.twilio.com/docs/quickstart/php/twiml)
* [TwiML Quickstart for Java](https://www.twilio.com/docs/quickstart/java/twiml)
* [TwiML Quickstart for C#](https://www.twilio.com/docs/quickstart/csharp/twiml)

## Issues and Support
Please file any issues you find here on Github: [Voice Swift Quickstart](https://github.com/twilio/voice-quickstart-swift).
Please ensure that you are not sharing any
[Personally Identifiable Information(PII)](https://www.twilio.com/docs/glossary/what-is-personally-identifiable-information-pii)
or sensitive account information (API keys, credentials, etc.) when reporting an issue.

For general inquiries related to the Voice SDK you can [file a support ticket](https://support.twilio.com/hc/en-us/requests/new).

## License
MIT
