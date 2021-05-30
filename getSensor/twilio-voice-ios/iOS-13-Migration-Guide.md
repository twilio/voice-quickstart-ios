# Migrating to iOS 13

iOS 13 introduced changes in push notifications handling. This document describes how to migrate to iOS 13 -

- [iOS 13 & Xcode 10 or below](#ios-13--xcode-10-or-below)
- [iOS 13 & Xcode 11](#ios-13--xcode-11)

## iOS 13 & Xcode 10 or below

This section provides information required for existings apps built with Xcode 10 or below. In order to comply with iOS 13 you must perform the following step and submit your app using Xcode 10 or below. If your app is built with Xcode 11 you must follow the steps noted in the next [section](#ios-13--xcode-11).

- Pass the credential data as the argument directly to the `[TwilioVoice registerWithAccessToken:deviceTokenData:completion:]` method.

    **Swift**

    ```.swift
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        TwilioVoice.register(withAccessToken: accessToken, deviceToken: credentials.token) { error in
            if let error = error {
                NSLog("An error occurred while registering: \(error.localizedDescription)")
            } else {
                NSLog("Successfully registered for VoIP push notifications.")
            }
        }
    }
    ```

    **Objective-C**

    ```.objective-c
    - (void)pushRegistry:(PKPushRegistry *)registry 
    didUpdatePushCredentials:(PKPushCredentials *)credentials 
                 forType:(NSString *)type {
        [TwilioVoice registerWithAccessToken:accessToken
                             deviceTokenData:credentials.token
                                  completion:^(NSError *error) {
             if (error) {
                 NSLog(@"An error occurred while registering: %@", [error localizedDescription]);
             } else {
                 NSLog(@"Successfully registered for VoIP push notifications.");
             }
         }];
    ```

## iOS 13 & Xcode 11

This section provides migration guides to support the new [PushKit push notification policy](https://developer.apple.com/documentation/pushkit/pkpushregistrydelegate/2875784-pushregistry) that iOS 13 and Xcode 11 introduced.

This new policy mandates that Apps built with Xcode 11 and running on iOS 13, which receive VoIP push notifications, must now report all PushKit push notifications to CallKit. Failure to do so will result in iOS 13 terminating the App and barring any further PushKit push notifications. You can read more about this policy and breaking changes [here](https://support.twilio.com/hc/en-us/articles/360035005593-iOS-13-Xcode-11-Breaking-Changes).

The SDK now handles incoming call cancellations internally. The “cancel” push notification is no longer required or supported by new releases of the SDK.

### Migration Guides

- [Migrate from Twilio Voice 3.x/4.x to 5.x](#migrating-from-twilio-voice-3x4x-to-5x)
- [Migrate from Twilio Voice 2.0 to 2.1](#migrating-from-twilio-voice-20-to-21)

## Migrating from Twilio Voice 3.x/4.x to 5.x

If your App supports incoming calls, you **MUST** perform the following steps to comply with the new policy:

1. Upgrade to Twilio Voice iOS SDK to 5.x
2. Your app must initialize `PKPushRegistry` with PushKit push type VoIP at the launch time on iOS 13. As mentioned in the [PushKit guidelines](https://developer.apple.com/documentation/pushkit/supporting_pushkit_notifications_in_your_app), the system can’t deliver push notifications to your app until you create a PKPushRegistry object for VoIP push type and set the delegate. If your app delays the initialization of `PKPushRegistry`, your app may receive outdated PushKit push notifications, and if your app decides not to report the received outdated push notifications to CallKit, iOS 13 may terminate your app.
3. Report the call to CallKit. Refer to this [example](https://github.com/twilio/voice-quickstart-swift/tree/master) for how to report the call to CallKit.
4. You must register via `[TwilioVoice registerWithAccessToken:deviceTokenData:completion:]` when your App starts. This ensures that your app no longer receives "cancel" push notifications. A "call" push notification, when passed to `[TwilioVoice handleNotification:delegate:delegateQueue:]`, will return a `TVOCallInvite` object to you synchronously via the `[TVONotificationDelegate callInviteReceived:]` method when `[TwilioVoice handleNotification:delegate:delegateQueue:]` is called. A `TVOCancelledCallInvite` will be raised asynchronously via `[TVONotificationDelegate cancelledCallInviteReceived:error:]` if any of the following events occur:
    - The call is prematurely disconnected by the caller.
    - The callee does not accept or reject the call in approximately 30 seconds.
    - The Voice SDK is unable to establish a connection to Twilio.
  
    You must retain the `TVOCallInvite` to be notified of a cancellation via `[TVONotificationDelegate cancelledCallInviteReceived:error:]`. A `TVOCancelledCallInvite` will not be raised if the `TVOCallInvite` is accepted or rejected.
  
    Failure to register with the new release of the SDK may result in app terminations since "cancel" push notifications will continue to be sent to your application and will not comply with the new PushKit push notification policy. If a "cancel" push notification is received, the `[TwilioVoice handleNotification:delegate:delegateQueue:]` method will now return `false`.
  
    To register with the new SDK when the app is launched:

    **Swift**
    
    ```.swift
    // AppDelegate.swift
    class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate {
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
            ...
            self.setupPushRegistry()
            ...
        }

        func setupPushRegistry() {
            var voipRegistry: PKPushRegistry
            voipRegistry.delegate = self
            voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
        }

        func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
            let accessToken = fetchAccessToken()
            TwilioVoice.register(withAccessToken: accessToken, deviceToken: credentials.token) { (error) in
                ...
            }
        }
    }
    ```

    **Objective-C**

    ```.objective-c
    // AppDelegate.m
    @interface AppDelegate () <PKPushRegistryDelegate>
    @property (nonatomic, strong) PKPushRegistry *voipRegistry;
    @end

    @implementation AppDelegate

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
        ...
        [self setupPushRegistry];
        ...
    }

    - (void)setupPushRegistry {
        self.voipRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
        self.voipRegistry.delegate = self;
        self.voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    }

    #pragma mark - PKPushRegistryDelegate
    - (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
        NSString *accessToken = [self fetchAccessToken];

        [TwilioVoice registerWithAccessToken:accessToken
                             deviceTokenData:credentials.token
                                  completion:^(NSError *error) {
            ...
        }];
    }

    @end
    ```

    Please note that if the app is updated but never launched to perform the registration, the mobile client will still receive "cancel" notifications, which could cause the app terminated by iOS if the VoIP push notification is not reported to CallKit as a new incoming call. To workaround and avoid app being terminated on iOS 13, upon receiving a "cancel" notification you can report a dummy incoming call to CallKit and then end it on the next tick:

    **Swift**

    ```.swift
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        if (payload.dictionaryPayload["twi_message_type"] as! String == "twilio.voice.cancel") {
            let callHandle = CXHandle(type: .generic, value: "alice")

            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = true
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false

            let uuid = UUID()

            callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
                ...
            }

            DispatchQueue.main.async {
                let endCallAction = CXEndCallAction(call: uuid)
                let transaction = CXTransaction(action: endCallAction)

                callKitCallController.request(transaction) { error in
                    ...
                }
            }

            return
        }
    }
    ```

    **Objective-C**

    ```.objective-c
    - (void)pushRegistry:(PKPushRegistry *)registry
    didReceiveIncomingPushWithPayload:(PKPushPayload *)payload
                 forType:(PKPushType)type
    withCompletionHandler:(void (^)(void))completion {
        if ([payload.dictionaryPayload[@"twi_message_type"] isEqualToString:@"twilio.voice.cancel"]) {
            CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"alice"];

            CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
            callUpdate.remoteHandle = callHandle;
            callUpdate.supportsDTMF = YES;
            callUpdate.supportsHolding = YES;
            callUpdate.supportsGrouping = NO;
            callUpdate.supportsUngrouping = NO;
            callUpdate.hasVideo = NO;

            NSUUID *uuid = [NSUUID UUID];

            [self.callKitProvider reportNewIncomingCallWithUUID:uuid update:callUpdate completion:^(NSError *error) {
                ...
            }];

            dispatch_async(dispatch_get_main_queue(), ^{
                CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:uuid];
                CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];

                [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
                    ...
                }];
            });

            return;
        }
    }
    ```

6. If you were previously toggling `enableInsights` or specifying a `region` via `TVOCallOptions`, you must now set the `insights` and `region` property on the `TwilioVoice` class. You must do so before `[TwilioVoice connectWithAccessToken:delegate:]` or `[TwilioVoice handleNotification:delegate:delegateQueue:]` is called.

You can reference the 5.x quickstart for [obj-c](https://github.com/twilio/voice-quickstart-objc) and [swift](https://github.com/twilio/voice-quickstart-swift) when migrating your application.

A summary of the API changes and new Insights events can be found in the [5.0.0 changelog](https://www.twilio.com/docs/voice/voip-sdk/ios/changelog#500).

## Migrating from Twilio Voice 2.0 to 2.1

If your App supports incoming calls, you **MUST** perform the following steps to comply with the new policy:

1. Upgrade to Twilio Voice iOS SDK to 2.1.0
2. Your app must initialize `PKPushRegistry` with PushKit push type VoIP at the launch time on iOS 13. As mentioned in the [PushKit guidelines](https://developer.apple.com/documentation/pushkit/supporting_pushkit_notifications_in_your_app), the system can’t deliver push notifications to your app until you create a PKPushRegistry object for VoIP push type and set the delegate. If your app delays the initialization of `PKPushRegistry`, your app may receive outdated PushKit push notifications, and if your app decides not to report the received outdated push notifications to CallKit, iOS 13 may terminate your app.
3. Report the call to CallKit. Refer to this [example](https://github.com/twilio/voice-quickstart-swift/tree/2.x) for how to report the call to CallKit.
4. Update how you decode the PushKit device token

    **Swift**
    
    ```.swift
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        ...
        let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
        ...
    }
    ```

    **Objective-C**
    
    ```.objective-c
    - (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
        ...
        const char *tokenBytes = [credentials.token bytes];
        NSMutableString *deviceTokenString = [NSMutableString string];
        for (NSUInteger i = 0; i < [credentials.token length]; ++i) {
            [deviceTokenString appendFormat:@"%02.2hhx", tokenBytes[i]];
        }
        ...
    }
    ```

    Not updating your App's PushKit device token parsing logic will result in the following error message when calling the `[TwilioVoice registerWithAccessToken:deviceToken:completion:]` method:

    ```
    Error Domain=com.twilio.voice.error Code=31301 "Http status: 400. Unexpected registration response." UserInfo={NSLocalizedDescription=Http status: 400. Unexpected registration response.}
    ```

5. You must register via `[TwilioVoice registerWithAccessToken:deviceToken:completion:]` when your App starts. This ensures that your app no longer receives “cancel” push notifications. A "call" push notification, when passed to `[TwilioVoice handleNotification:delegate:]`, will return a `TVOCallInvite` object to you synchronously via the `[TVONotificationDelegate callInviteReceived:]` method when `[TwilioVoice handleNotification:delegate:]` is called. The SDK will invoke the `[TVONotificationDelegate callInviteReceived:]` method asynchronously with a `TVOCallInvite` object of state `TVOCallInviteStateCanceled` if any of the following events occur:
    - The call is prematurely disconnected by the caller.
    - The callee does not accept or reject the call in approximately 30 seconds.
    - The Voice SDK is unable to establish a connection to Twilio.
    The `[TVONotificationDelegate callInviteReceived:]` method will not be raised with a `TVOCallInvite` object of state `TVOCallInviteStateCanceled` if the `TVOCallInivte` is accepted or rejected.
  
    Failure to register with the new release of the SDK may result in app terminations since "cancel" push notifications will continue to be sent to your application and will not comply with the new PushKit push notification policy. A new error [`TVOErrorUnsupportedCancelMessageError (31302)`](https://www.twilio.com/docs/api/errors/31302) is raised when a "cancel" push notification is provided to `[TwilioVoice handleNotification:delegate:]` via `[TVONotificationDelegate notificationError:]`.

    To register with the new SDK when the app is launched:
 
    **Swift**
    
    ```.swift
    // AppDelegate.swift
    class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate {
        func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
            ...
            self.setupPushRegistry()
            ...
        }

        func setupPushRegistry() {
            var voipRegistry: PKPushRegistry
            voipRegistry.delegate = self
            voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
        }

        func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
            let accessToken = fetchAccessToken()
            let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()

            TwilioVoice.register(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
                ...
            }
        }
    }
    ```

    **Objective-C**

    ```.objective-c
    // AppDelegate.m
    @interface AppDelegate () <PKPushRegistryDelegate>
    @property (nonatomic, strong) PKPushRegistry *voipRegistry;
    @end

    @implementation AppDelegate

    - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
        ...
        [self setupPushRegistry];
        ...
    }

    - (void)setupPushRegistry {
        self.voipRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
        self.voipRegistry.delegate = self;
        self.voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    }

    #pragma mark - PKPushRegistryDelegate
    - (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
        const char *tokenBytes = [credentials.token bytes];
        NSMutableString *deviceTokenString = [NSMutableString string];
        for (NSUInteger i = 0; i < [credentials.token length]; ++i) {
            [deviceTokenString appendFormat:@"%02.2hhx", tokenBytes[i]];
        }
        NSString *accessToken = [self fetchAccessToken];

        [TwilioVoice registerWithAccessToken:accessToken
                                 deviceToken:deviceTokenString
                                  completion:^(NSError *error) {
            ...
        }];
    }

    @end
    ```

    Please note that if the app is updated but never launched to perform the registration, the mobile client will still receive "cancel" notifications, which could cause the app terminated by iOS if the VoIP push notification is not reported to CallKit as a new incoming call. To workaround and avoid app being terminated on iOS 13, upon receiving a "cancel" notification you can report a dummy incoming call to CallKit and then end it on the next tick:

    **Swift**

    ```.swift
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        if (payload.dictionaryPayload["twi_message_type"] as! String == "twilio.voice.cancel") {
            let callHandle = CXHandle(type: .generic, value: "alice")

            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = true
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false

            let uuid = UUID()

            callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
                ...
            }

            DispatchQueue.main.async {
                let endCallAction = CXEndCallAction(call: uuid)
                let transaction = CXTransaction(action: endCallAction)

                callKitCallController.request(transaction) { error in
                    ...
                }
            }

            return
        }
    }
    ```

    **Objective-C**

    ```.objective-c
    - (void)pushRegistry:(PKPushRegistry *)registry
    didReceiveIncomingPushWithPayload:(PKPushPayload *)payload
                 forType:(PKPushType)type
    withCompletionHandler:(void (^)(void))completion {
        if ([payload.dictionaryPayload[@"twi_message_type"] isEqualToString:@"twilio.voice.cancel"]) {
            CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:@"alice"];

            CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
            callUpdate.remoteHandle = callHandle;
            callUpdate.supportsDTMF = YES;
            callUpdate.supportsHolding = YES;
            callUpdate.supportsGrouping = NO;
            callUpdate.supportsUngrouping = NO;
            callUpdate.hasVideo = NO;

            NSUUID *uuid = [NSUUID UUID];

            [self.callKitProvider reportNewIncomingCallWithUUID:uuid update:callUpdate completion:^(NSError *error) {
                ...
            }];

            dispatch_async(dispatch_get_main_queue(), ^{
                CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:uuid];
                CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];

                [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
                    ...
                }];
            });

            return;
        }
    }
    ```

6. If you were specifying a region via the `TwilioVoice.h` region property you must now do so before `[TwilioVoice call:params:delegate:]` or `[TwilioVoice handleNotification:delegate:]` is called.

You can reference the 2.1 quickstart for [obj-c](https://github.com/twilio/voice-quickstart-objc/tree/2.x) and [swift](https://github.com/twilio/voice-quickstart-swift/tree/2.x) when migrating your application.

A summary of the API changes and new Insights events can be found in the [2.1.0 changelog](https://www.twilio.com/docs/voice/voip-sdk/ios/2x-changelog#210-september-5-2019).
