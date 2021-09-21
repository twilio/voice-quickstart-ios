## Making Calls from Call History

The document show a quick example of how to make outgoing calls from recent call history or from contacts.

### Steps

#### 1. Specify supported handle types when initializing the `CXProvider` object. User activity callback will not be triggered if this is not set.

```.swift
    let configuration = CXProviderConfiguration(localizedName: "Voice Quickstart")
    configuration.maximumCallGroups = 1
    configuration.maximumCallsPerCallGroup = 1

    // Specify supported handle types so the app gets user activity callback when a call is made from call history
    configuration.supportedHandleTypes = [.generic, .phoneNumber]

    if let provider = CXProvider(configuration: configuration) {
        provider.setDelegate(self, queue: nil)
    }

```

```.objc
    CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:@"Voice"];
    configuration.maximumCallGroups = 1;
    configuration.maximumCallsPerCallGroup = 1;

    // Specify supported handle types so the app gets user activity callback when a call is made from call history
    configuration.supportedHandleTypes = [NSSet setWithArray:@[@(CXHandleTypeGeneric), @(CXHandleTypePhoneNumber)]];
            
    self.callKitProvider = [[CXProvider alloc] initWithConfiguration:configuration];
    [self.callKitProvider setDelegate:self queue:nil];

```

#### 2. Implement the `[UIApplication continueUserActivity:restorationHandler:]` delegate method and use the `INStartAudioCallIntent` to start a call.

```.swift
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        if let callIntent = userActivity.interaction?.intent as? INStartAudioCallIntent,
           let contact = callIntent.contacts?[0] {
            guard let handle = contact.personHandle?.value else { return false }
            // Start a new call with CallKit
            makeCall(handle)
        }
        
        return true
    }
```

```.objc
- (BOOL)application:(UIApplication *)application
continueUserActivity:(NSUserActivity *)userActivity
 restorationHandler:(void(^)(NSArray<id<UIUserActivityRestoring>> *restorableObjects))restorationHandler {

    INStartAudioCallIntent *callIntent = (INStartAudioCallIntent *)userActivity.interaction.intent;

    if (callIntent.contacts[0]) {
        NSString *handle = callIntent.contacts[0].personHandle.value;
        if ([handle length] > 0) {
            // Start a new call with CallKit
            [self makeCallWithHandle:handle];
        }
    }

    return YES;
}
```
