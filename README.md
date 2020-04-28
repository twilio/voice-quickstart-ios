## Twilio Voice Quickstart for iOS

> NOTE: These sample applications use the Twilio Voice 5.x APIs. For examples using our 2.x APIs, please see the [2.x](https://github.com/twilio/voice-quickstart-swift/tree/2.x) branch. If you are using SDK 2.x, we highly recommend planning your migration to 5.0 as soon as possible. Support for 2.x will cease 1/1/2020. Until then, SDK 2.x will only receive fixes for critical or security related issues.

> Please see our [iOS 13 Migration Guide](https://github.com/twilio/twilio-voice-ios/blob/Releases/iOS-13-Migration-Guide.md) for the latest information on iOS 13.

## Get started with Voice on iOS:
* [Quickstart](#quickstart) - Run the swift quickstart app
* [Examples](#examples) - Sample applications
* [Access Tokens](https://github.com/twilio/voice-quickstart-swift/blob/master/Docs/access-tokens.md) - Using access tokens
* [Managing Audio Interruptions](https://github.com/twilio/voice-quickstart-swift/blob/master/Docs/managing-audio-interruptions.md) - Managing audio interruptions
* [Managing Push Credentials](https://github.com/twilio/voice-quickstart-swift/blob/master/Docs/managing-push-credentials.md) - Managing push credentials
* [More Documentation](#more-documentation) - More documentation related to the Voice iOS SDK
* [Issues and Support](#issues-and-support) - Filing issues and general support

## Voice iOS SDK Versions
* [Migration Guide from 4.x to 5.x](https://github.com/twilio/twilio-voice-ios/blob/Releases/iOS-13-Migration-Guide.md) - Migrating from 4.x to 5.x
* [4.0 New Features](https://github.com/twilio/voice-quickstart-swift/blob/master/Docs/new-features-4.0.md) - New features in 4.0
* [Migration Guide from 3.x to 4.x](https://github.com/twilio/voice-quickstart-swift/blob/master/Docs/migration-guide-3.x-4.x.md) - Migrating from 3.x to 4.x
* [3.0 New Features](https://github.com/twilio/voice-quickstart-swift/blob/master/Docs/new-features-3.0.md) - New features in 3.0
* [Migration Guide from 2.x to 3.x](https://github.com/twilio/voice-quickstart-swift/blob/master/Docs/migration-guide-2.x-3.x.md) - Migrating from 2.x to 3.x

## Quickstart
To get started with the quickstart application follow these steps. Steps 1-6 will enable the application to make a call. The remaining steps 6-9 will enable the application to receive incoming calls in the form of push notifications using Apple’s VoIP Service.

1. [Install the TwilioVoice framework](#bullet1)
2. [Use Twilio CLI to deploy access token and TwiML application to Twilio Serverless](#bullet2)
3. [Create a TwiML application for the access token](#bullet3)
4. [Generate an access token for the quickstart](#bullet4)
5. [Run the Swift Quickstart app](#bullet5)
6. [Create a Push Credential with your VoIP Service Certificate](#bullet6)
7. [Receive an incoming call](#bullet7)
8. [Make client to client call](#bullet8)
9. [Make client to PSTN call](#bullet9)

### <a name="bullet1"></a>1. Install the TwilioVoice framework

**Carthage**

Add the following line to your Cartfile

```
github "twilio/twilio-voice-ios"
```

Then run `carthage bootstrap` (or `carthage update` if you are updating your SDKs)

On your application targets’ "Build Phases" settings tab, click the "+" icon and choose "New Run Script Phase". Create a Run Script in which you specify your shell (ex: `/bin/sh`), add the following contents to the script area below the shell:

```
/usr/local/bin/carthage copy-frameworks
```

Add the paths to the frameworks you want to use under "Input Files", e.g.:

```
$(SRCROOT)/Carthage/Build/iOS/TwilioVoice.framework
```

**Cocoapods**

Under the quickstart path, run `pod install` and let the Cocoapods library create the workspace for you.
Once Cocoapods finishes installing, open the `VoiceQuickstart.xcworkspace` and you will find a basic Swift quickstart project that works with CallKit.

Note: You may need to update the [CocoaPods Master Spec Repo](https://github.com/CocoaPods/Specs) by running `pod repo update master` in order to fetch the latest specs for TwilioVoice.

### <a name="bullet2"></a>2. Use Twilio CLI to deploy access token and TwiML application to Twilio Serverless

You must have the following installed:

* [Node.js v10+](https://nodejs.org/en/download/)
* NPM v6+ (comes installed with newer Node versions)

Run `npm install` to install all dependencies from NPM.

Install twilio-cli with:

    $ npm install -g twilio-cli

Login to the Twilio CLI. You will be prompted for your Account SID and Auth Token, both of which you can find on the dashboard of your [Twilio console](https://twilio.com/console).

    $ twilio login

This app requires the [Serverless plug-in](https://github.com/twilio-labs/plugin-serverless). Install the CLI plugin with:

    $ twilio plugins:install @twilio-labs/plugin-serverless

Before deploying, create a `Server/.env` by copying from `Server/.env.example`

    $ cp Server/.env.example Server/.env

Update `Server/.env` with your Account SID, auth token, API Key and secret

    ACCOUNT_SID=ACxxxx
    AUTH_TOKEN=xxxxxx
    API_KEY=SKxxxx
    API_SECRET=xxxxxx
    APP_SID=APxxxx
    PUSH_CREDENTIAL_SID=CRxxxx

The app is deployed to Twilio Serverless with the `serverless` plug-in:

    $ cd Server
    $ twilio serverless:deploy

The server example that comes with the quickstart is in Node.js. You can find the server starter project in the following languages.

* [voice-quickstart-server-java](https://github.com/twilio/voice-quickstart-server-java)
* [voice-quickstart-server-node](https://github.com/twilio/voice-quickstart-server-node)
* [voice-quickstart-server-php](https://github.com/twilio/voice-quickstart-server-php)
* [voice-quickstart-server-python](https://github.com/twilio/voice-quickstart-server-python)

Follow the instructions in the server's README to get the application server up and running locally and accessible via the public Internet.

### <a name="bullet3"></a>3. Create a TwiML application for the Access Token
Next, we need to create a TwiML application. A TwiML application identifies a public URL for retrieving [TwiML call control instructions](https://www.twilio.com/docs/api/twiml). When your iOS app makes a call to the Twilio cloud, Twilio will make a webhook request to this URL, your application server will respond with generated TwiML, and Twilio will execute the instructions you’ve provided.

Use Twilio CLI to create a TwiML app with the `make-call` endpoint you have just deployed

    $ twilio api:core:applications:create \
        --friendly-name=my-twiml-app \
        --voice-method=post \
        --voice-url="https://my-quickstart-dev.twil.io/make-call" 

### <a name="bullet4"></a>4. Generate an access token for the quickstart

You will need the `token` plug-in

    $ twilio plugins:install @twilio-labs/plugin-token

Use the TwiML App SID you just created to generate an access token

    $ twilio token:voice --identity=alice --voice-app-sid=APxxxx

Copy the access token string. Your iOS app will use this token to connect to Twilio.

### <a name="bullet5"></a>5. Run the Swift Quickstart app

Now let’s go back to the `VoiceQuickstart.xcworkspace`. Update the placeholder of `accessToken` with access token string you just copied

```swift
import UIKit
import AVFoundation
import PushKit
import CallKit
import TwilioVoice

let accessToken = "PASTE_YOUR_ACCESS_TOKEN_HERE"
let twimlParamTo = "to"

let kCachedDeviceToken = "CachedDeviceToken"

class ViewController: UIViewController {
    ...
}
```

Build and run the app. Leave the text field empty and press the call button to start a call. You will hear the congratulatory message. Support for dialing another client or number is described in steps 10 and 11. Tap "Hang Up" to disconnect.

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/hang-up.png"/></kbd>

### <a name="bullet6"></a>6. Create a Push Credential with your VoIP Service Certificate
The Programmable Voice SDK uses Apple’s VoIP Services to let your application know when it is receiving an incoming call. If you want your users to receive incoming calls, you’ll need to enable VoIP Services in your application and generate a VoIP Services Certificate.

Go to [Apple Developer portal](https://developer.apple.com/) and generate a VoIP Service Certificate.

Once you have generated the VoIP Services Certificate, you will need to provide the certificate and key to Twilio so that Twilio can send push notifications to your app on your behalf.

Export your VoIP Service Certificate as a .p12 file from Keychain Access and extract the certificate and private key from the .p12 file using the `openssl` command. 

    $ openssl pkcs12 -in PATH_TO_YOUR_P12 -nokeys -out cert.pem -nodes
    $ openssl pkcs12 -in PATH_TO_YOUR_P12 -nocerts -out key.pem -nodes
    $ openssl rsa -in key.pem -out key.pem

Use Twilio CLI to create a Push Credential using the cert and key.

    $ twilio api:chat:v2:credentials:create \
        --type=apn \
        --sandbox \
        --friendly-name="voice-push-credential (sandbox)" \
        --certificate="$(cat PATH_TO_CERT_PEM)" \
        --private-key="$(cat PATH_TO_KEY_PEM)"
    
The `--sandbox` option tells Twilio to send the notification requests to the sandbox endpoint of Apple's APNS service. 

Once the app is ready for distribution or store submission, create a separate Push Credential with a new VoIP Service certificate without the `--sandbox` option.

Now let's generate another access token and add the Push Credential to the Voice Grant.

    $ twilio token:voice \
        --identity=alice \
        --voice-app-sid=APxxxx \
        --push-credential-sid=CRxxxxs

### <a name="bullet7"></a>7. Receive an incoming call
You are now ready to receive incoming calls. Paste the access token generated from step 6 and rebuild your app. Hit your application server's **/place-call** endpoint: `https://my-quickstart-dev.twil.io/place-call?to=alice`. This will trigger a Twilio REST API request that will make an inbound call to the identity registered on your mobile app. Once your app accepts the call, you should hear a congratulatory message.

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/incoming-call.png"/></kbd>

### <a name="bullet8"></a>8. Make client to client call
To make client to client calls, you need the application running on two devices. To run the application on an additional device, make sure you use a different identity in your access token when registering the new device. 

Use the text field to specify the identity of the call receiver, then tap the "Call" button to make a call. The TwiML parameters used in `TwilioVoice.connect()` method should match the name used in the server.

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/client-to-client.png"/></kbd>

### <a name="bullet9"></a>9. Make client to PSTN call
A verified phone number is one that you can use as your Caller ID when making outbound calls with Twilio. This number has not been ported into Twilio and you do not pay Twilio for this phone number.

To make client to number calls, first get a valid Twilio number to your account via https://www.twilio.com/console/phone-numbers/verified. Update your server code and replace the `callerNumber` variable with the verified number. Restart the server so it uses the new value.

<kbd><img width="300px" src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/client-to-pstn.png"/></kbd>

## <a name="examples"></a> Examples

You will also find additional examples that provide more advanced use cases of the Voice SDK:

- [AudioDevice](AudioDeviceExample) - Provide your own means to playback and record audio using a custom `TVOAudioDevice` and [CoreAudio](https://developer.apple.com/documentation/coreaudio).

## More Documentation
You can find more documentation on getting started as well as our latest AppleDoc below:

* [Getting Started](https://www.twilio.com/docs/api/voice-sdk/ios/getting-started)
* [TwilioVoice SDK API Doc](https://twilio.github.io/twilio-voice-ios/docs/latest/)

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
