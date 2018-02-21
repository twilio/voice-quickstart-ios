# Twilio Voice Swift Quickstart for iOS

## Get started with Voice on iOS:
* [Quickstart](#quickstart) - Run the quickstart app
* [Access Tokens](#access-tokens) - Using access tokens
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

<kbd><img src="Images/carthage.png"/></kbd>

**Cocoapods**

Under the quickstart path, run `pod install` and let the Cocoapods library create the workspace for you. Also please make sure to use **Cocoapods v1.0 and later**.
Once Cocoapods finishes installing, open the `SwiftVoiceQuickstart.xcworkspace` and you will find a basic Swift quickstart project and a CallKit quickstart project.

Note: You may need to update the [CocoaPods Master Spec Repo](https://github.com/CocoaPods/Specs) by running `pod repo update master` in order to fetch the latest specs for TwilioVoice.

### <a name="bullet2"></a>2. Create a Voice API key
Go to the [Voice API Keys](https://www.twilio.com/console/voice/runtime/api-keys) page and create a new API key:

<kbd><img src="Images/create-api-key.png"/></kbd>

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

<kbd><img src="Images/create-twiml-app.png"/></kbd>

As you can see we’ve used our [ngrok](https://ngrok.com/) public address in the Request URL field above.
Save your TwiML Application configuration, and grab the **TwiML Application SID** (a long identifier beginning with the characters `AP`).

### <a name="bullet5"></a>5. Configure your application server
Let's put the remaining `APP_SID` configuration info into `server.py` 

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

<kbd><img height="667px" src="Images/build-and-run.png"/></kbd>

Leave the text field empty and press the call button to start a call. You will hear the congratulatory message. Support for dialing another client or number is described in steps 11 and 12. Tap "Hang Up" to disconnect.

<kbd><img height="667px" src="Images/hang-up.png"/></kbd>

### <a name="bullet7"></a>7. Create VoIP Service Certificate
The Programmable Voice SDK uses Apple’s VoIP Services to let your application know when it is receiving an incoming call. If you want your users to receive incoming calls, you’ll need to enable VoIP Services in your application and generate a VoIP Services Certificate.

Go to [Apple Developer portal](https://developer.apple.com/) and you’ll need to do the following:
- An Apple Developer membership to be able to create the certificate.
- Make sure your App ID has the “Push Notifications” service enabled.
- Create a corresponding Provisioning Profile for your app ID.
- Create an [Apple VoIP Services Certificate](https://developer.apple.com/library/prerelease/content/documentation/Performance/Conceptual/EnergyGuide-iOS/OptimizeVoIP.html#//apple_ref/doc/uid/TP40015243-CH30-SW1) for this app. 

<kbd><img src="Images/create-voip-service-certificate.png"/></kbd>

### <a name="bullet8"></a>8. Create a Push Credential with your VoIP Service Certificate
Once you have generated the VoIP Services Certificate, you will need to upload it to Twilio so that Twilio can send push notifications to your app on your behalf.

Export your VoIP Service Certificate as a .p12 file, then extract the certificate and private key from the .p12 file using the `openssl` command

    $> openssl pkcs12 -in PATH_TO_YOUR_P12 -nocerts -out key.pem
    $> openssl rsa -in key.pem -out key.pem
    $> openssl pkcs12 -in PATH_TO_YOUR_P12 -clcerts -nokeys -out cert.pem

Go to the [Push Credentials page](https://www.twilio.com/console/voice/credentials) and create a new Push Credential. Paste the certificate and private key extracted from your certificate. You must paste the keys in as plaintext:

* For the `cert.pem` you should paste everything from `-----BEGIN CERTIFICATE-----` to `-----END CERTIFICATE-----`. 
* For the `key.pem` you should paste everything from `-----BEGIN RSA PRIVATE KEY-----` to `-----END RSA PRIVATE KEY-----`.

**Remember to check the “Sandbox” option**. This is important. The VoIP Service Certificate you generated can be used both in production and with Apple's sandbox infrastructure. Checking this box tells Twilio to send your pushes to the Apple sandbox infrastructure which is appropriate with your development provisioning profile.

Once the app is ready for store submission, update the plist with “APS Environment: production” and create another Push Credential with the same VoIP Certificate but without checking the sandbox option.

<kbd><img src="Images/add-push-credential.png"/></kbd>

Now let's go back to `server.py` and update the Push Credential SID. The Push Credential SID will now be embedded in your access token.

    PUSH_CREDENTIAL_SID = 'CR***'

### <a name="bullet9"></a>9. Configure Xcode project settings for push notifications
On the project’s Capabilities tab, enable “**Push Notifications**”.
In Xcode 8 or earlier, enable both “**Voice over IP**” and “**Audio, AirPlay and Picture in Picture**” capabilities in the Background Modes

<kbd><img src="Images/xcode-project-capabilities.png"/></kbd>

In Xcode 9+, add a "**UIBackgroundModes**" dictionary with "**audio**" and "**voip**" to the app's plist.
```
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
  <string>voip</string>
</array>
```

### <a name="bullet10"></a>10. Receive an incoming call
You are now ready to receive incoming calls. Rebuild your app and hit your application server's **/placeCall** endpoint: `https://{YOUR_SERVER_URL}/placeCall` (If your app server is written in PHP, then you need `.php` extension at the end). This will trigger a Twilio REST API request that will make an inbound call to your mobile app. Once your app accepts the call, you should hear a congratulatory message.

<kbd><img height="667px" src="Images/incoming-call.png"/></kbd>

### <a name="bullet11"></a>11. Make client to client call
To make client to client calls, you need the application running on two devices. To run the application on an additional device, make sure you use a different identity in your access token when registering the new device. For example, change `kIdentity` to `bob` and run the application

```swift
let accessTokenEndpoint = "/accessToken"
let identity = "bob"
let twimlParamTo = "to"
```

Use the text field to specify the identity of the call receiver, then tap the “Call” button to make a call. The TwiML parameters used in `TwilioVoice.call()` method should match the name used in the server.

<kbd><img height="667px" src="Images/client-to-client.png"/></kbd>

### <a name="bullet12"></a>12. Make client to PSTN call
A verified phone number is one that you can use as your Caller ID when making outbound calls with Twilio. This number has not been ported into Twilio and you do not pay Twilio for this phone number.

To make client to number calls, first get a valid Twilio number to your account via https://www.twilio.com/console/phone-numbers/verified. Update `server.py` and replace `CALLER_NUMBER` with the verified number. Restart the server so it uses the new value. Voice Request URL of your TwiML application should point to the public URL of your application server’s `/makeCall` endpoint.

<kbd><img height="667px" src="Images/client-to-pstn.png"/></kbd>

## Access Tokens

The access token generated by your server component is a [jwt](jwt.io) that contains a `grant` for Programmable Voice, an `identity` that you specify, and a `time-to-live` that sets the lifetime of the generated access token. The default `time-to-live` is 1 hour and is configurable up to 24 hours using the Twilio helper libraries.

### Uses

In the iOS SDK the access token is used for the following:

1. To make an outgoing call via `TwilioVoice.call(...)`
2. To register or unregister for incoming notifications using VoIP Push Notifications via `TwilioVoice.registerWithAccessToken(...)` and `TwilioVoice.unregisterWithAccessToken(...)`. Once registered, incoming notifications are handled via a `TVOCallInvite` where you can choose to accept or reject the invite. When accepting the call an access token is not required. Internally the `TVOCallInvite` has its own access token that ensures it can connect to our infrastructure.

### Managing Expiry

As mentioned above, an access token will eventually expire. If an access token has expired, our infrastructure will return error `TVOErrorAccessTokenExpired`/`20104` via `TVOCallDelegate` or a completion error when registering.

There are number of techniques you can use to ensure that access token expiry is managed accordingly:

- Always fetch a new access token from your access token server before making an outbound call.
- Retain the access token until getting a `TVOErrorAccessTokenExpired`/`20104` error before fetching a new access token.
- Retain the access token along with the timestamp of when it was requested so you can verify ahead of time whether the token has already expired based on the `time-to-live` being used by your server.
- Prefetch the access token whenever the `UIApplication`, or `UIViewController` associated with an outgoing call is created.

## More Documentation
You can find more documentation on getting started as well as our latest AppleDoc below:

* [Getting Started](https://www.twilio.com/docs/api/voice-sdk/ios/getting-started)
* [AppleDoc](https://media.twiliocdn.com/sdk/ios/voice/latest/docs)

## Twilio Helper Libraries
To learn more about how to use TwiML and the Programmable Voice Calls API, check out our TwiML quickstarts:

* [TwiML Quickstart for Python](https://www.twilio.com/docs/quickstart/python/twiml)
* [TwiML Quickstart for Ruby](https://www.twilio.com/docs/quickstart/ruby/twiml)
* [TwiML Quickstart for PHP](https://www.twilio.com/docs/quickstart/php/twiml)
* [TwiML Quickstart for Java](https://www.twilio.com/docs/quickstart/java/twiml)
* [TwiML Quickstart for C#](https://www.twilio.com/docs/quickstart/csharp/twiml)

## Issues and Support
Please file any issues you find here on Github: [Voice Swift Quickstart](https://github.com/twilio/voice-quickstart-swift).

For general inquiries related to the Voice SDK you can [file a support ticket](https://support.twilio.com/hc/en-us/requests/new).

## License
MIT
