## Managing Push Credentials

A push credential is a record for a push notification channel, for iOS this push credential is a push notification channel record for APNS VoIP. Push credentials are managed in the console under [Mobile Push Credentials](https://www.twilio.com/console/voice/sdks/credentials).

Whenever a registration is performed via `TwilioVoice.registerWithAccessToken:deviceTokenData:completion` in the iOS SDK the `identity` and the `Push Credential SID` provided in the JWT based access token, along with the `device token` are used as a unique address to send APNS VoIP push notifications to this application instance whenever a call is made to reach that `identity`. Using `TwilioVoice.unregisterWithAccessToken:deviceTokenData:completion` removes the association for that `identity`.

### Updating a Push Credential

If you need to change or update your credentials provided by Apple you can do so by selecting the Push Credential in the [console](https://www.twilio.com/console/voice/sdks/credentials) and adding your new `certificate` and `private key` in the text box provided on the Push Credential page shown below:

<kbd><img height="500px" src="https://github.com/twilio/voice-quickstart-swift/raw/master/Images/update_push_credential.png"/></kbd>

### Deleting a Push Credential

We **do not recommend that you delete a Push Credential** unless the application that it was created for is no longer being used.

If **your APNS VoIP certificate is expiring soon or has expired you should not delete your Push Credential**, instead you should update the Push Credential by following the `Updating a Push Credential`  section.

When a Push Credential is deleted **any associated registrations made with this Push Credential will be deleted**. Future attempts to reach an `identity` that was registered using the Push Credential SID of this deleted push credential **will fail**.

If you are certain you want to delete a Push Credential you can click on `Delete this Credential` on the [console](https://www.twilio.com/console/voice/sdks/credentials) page of the selected Push Credential.

Please ensure that after deleting the Push Credential you remove or replace the Push Credential SID when generating new access tokens.