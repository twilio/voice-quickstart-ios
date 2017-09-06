# Twilio Voice Swift Quickstart for iOS

## Get started with Voice on iOS:
* [Quickstart](#quickstart) - Run the quickstart app
* [More Documentation](#more-documentation) - More documentation related to the Voice iOS SDK
* [Issues and Support](#issues-and-support) - Filing issues and general support

## Quickstart
To get started with the quickstart application follow these steps. Steps 1-6 will enable the application to make a call. The remaining steps 7-10 will enable the application to receive incoming calls in the form of push notifications using Apple’s VoIP Service.

1. [Install the TwilioVoice framework using Cocoapods](#bullet1)
2. [Create a Voice API key](#bullet2)
3. [Configure a server to generate an access token to be used in the app](#bullet3)
4. [Create a TwiML application](#bullet4)
5. [Configure your application server](#bullet5)
6. [Run the app](#bullet6)
7. [Create a VoIP Service Certificate](#bullet7)
8. [Create a Push Credential with your VoIP Service Certificate](#bullet8)
9. [Configure Xcode project settings for VoIP push notifications](#bullet9)
10. [Receive an incoming call](#bullet10)

### <a name="bullet1"></a>1. Install the TwilioVoice framework using Cocoapods
Under the quickstart path, run `pod install` and let the Cocoapods library create the workspace for you. Also please make sure to use **Cocoapods v1.0 and later**.
Once Cocoapods finishes installing, open the `SwiftVoiceQuickstart.xcworkspace` and you will find a basic Swift quickstart project and a CallKit quickstart project.

### <a name="bullet2"></a>2. Create a Voice API key
Go to the [Voice API Keys](https://www.twilio.com/console/voice/runtime/api-keys) page and create a new API key:

<img src="Images/create-api-key.png"/>

**Save the generated `API_KEY` and `API_KEY_SECRET` in your notepad**. You will need them in the next step.

### <a name="bullet3"></a>3. Configure a server to generate an access token to be used in the app
Download the [starter project for the server](https://github.com/twilio/voice-quickstart-server-python).
Follow the instructions in the README to get the application server up and running locally and accessible via the public Internet. For now just replace the **Twilio Account SID** that you can obtain from the [console](https://www.twilio.com/console), and the `API_KEY` and `API_SECRET` you obtained in the previous step. 
    
    ACCOUNT_SID = 'AC***'
    API_KEY = 'SK***'
    API_KEY_SECRET = '***'

### <a name="bullet4"></a>4. Create a TwiML application
Next, we need to create a TwiML application. A TwiML application identifies a public URL for retrieving [TwiML call control instructions](https://www.twilio.com/docs/api/twiml). When your iOS app makes a call to the Twilio cloud, Twilio will make a webhook request to this URL, your application server will respond with generated TwiML, and Twilio will execute the instructions you’ve provided.
To create a TwiML application, go to the [TwiML app page](https://www.twilio.com/console/voice/dev-tools/twiml-apps). Create a new TwiML application, and use the public URL of your application server’s `/outgoing` endpoint as the Voice Request URL.

<img src="Images/create-twiml-app.png"/>

As you can see we’ve used our [ngrok](https://ngrok.com/) public address in the Request URL field above.
Save your TwiML Application configuration, and grab the **TwiML Application SID** (a long identifier beginning with the characters `AP`).

### <a name="bullet5"></a>5. Configure your application server
Let's put the remaining `APP_SID` configuration info into `server.py` 

    ACCOUNT_SID = 'AC***'
    API_KEY = 'SK***'
    API_KEY_SECRET = '***'
    APP_SID = 'AP***'

Once you’ve done that, restart the server so it uses the new configuration info. Now it's time to test.

Open up a browser and visit the URL for your application server's **Access Token endpoint**: `https://{YOUR-SERVER}/accessToken`. If everything is configured correctly, you should see a long string of letters and numbers, which is a Twilio Access Token. Your iOS app will use a token like this to connect to Twilio.

### <a name="bullet6"></a>6. Run the app
Now let’s go back to the `SwiftVoiceQuickstart.xcworkspace`. Update the placeholder of `baseURLString` with your ngrok public URL

<img src="Images/update-base-url.png"/>

Build and run the app

<img height="667px" src="Images/build-and-run.png"/>

Tap the “Place Outgoing Call” button to make a call, then tap “Hang Up” to disconnect

<img height="667px" src="Images/hang-up.png"/>

### <a name="bullet7"></a>7. Create VoIP Service Certificate
The Programmable Voice SDK uses Apple’s VoIP Services to let your application know when it is receiving an incoming call. If you want your users to receive incoming calls, you’ll need to enable VoIP Services in your application and generate a VoIP Services Certificate.

Go to [Apple Developer portal](https://developer.apple.com/) and you’ll need to do the following:
- Make sure your App ID has the “Push Notifications” service enabled.
- Create a corresponding Provisioning Profile for your app ID.
- Create an [Apple VoIP Services Certificate](https://developer.apple.com/library/prerelease/content/documentation/Performance/Conceptual/EnergyGuide-iOS/OptimizeVoIP.html#//apple_ref/doc/uid/TP40015243-CH30-SW1) for this app. 

<img src="Images/create-voip-service-certificate.png"/>

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

<img src="Images/add-push-credential.png"/>

Now let's go back to `server.py` and update the Push Credential SID. The Push Credential SID will now be embedded in your access token.

    PUSH_CREDENTIAL_SID = 'CR***'

### <a name="bullet9"></a>9. Configure Xcode project settings for push notifications
On the project’s Capabilities tab, enable “**Push Notifications**”, and enable both “**Voice over IP**” and “**Audio, AirPlay and Picture in Picture**” capabilities in the Background Modes

<img src="Images/xcode-project-capabilities.png"/>

### <a name="bullet10"></a>10. Receive an incoming call
You are now ready to receive incoming calls. Rebuild your app and hit your application server's **/placeCall** endpoint: `https://{YOUR-SERVER}/placeCall`. This will trigger a Twilio REST API request that will make an inbound call to your mobile app. Once your app accepts the call, you should hear a congratulatory message.

<img height="667px" src="Images/incoming-call.png"/>

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
