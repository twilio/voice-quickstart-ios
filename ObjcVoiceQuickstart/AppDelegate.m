//
//  AppDelegate.m
//  Twilio Voice with Quickstart - Objective-C
//
//  Copyright © 2016 Twilio, Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"

@import TwilioVoice;

@interface AppDelegate () <PKPushRegistryDelegate>

@property (nonatomic, weak) id<PushKitUpdateDelegate> pushKitUpdateDelegate;
@property (nonatomic, strong) PKPushRegistry *voipRegistry;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"Twilio Voice Version: %@", [TwilioVoice sdkVersion]);
    
    ViewController* viewController = (ViewController*)self.window.rootViewController;
    self.pushKitUpdateDelegate = viewController;
    [self initializePushKit];
    
    return YES;
}

- (void)initializePushKit {
    self.voipRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
    self.voipRegistry.delegate = self;
    self.voipRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - PKPushRegistryDelegate
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(NSString *)type {
    NSLog(@"pushRegistry:didUpdatePushCredentials:forType:");

    if ([type isEqualToString:PKPushTypeVoIP]) {
        if (self.pushKitUpdateDelegate && [self.pushKitUpdateDelegate respondsToSelector:@selector(credentialsUpdated:)]) {
            [self.pushKitUpdateDelegate credentialsUpdated:credentials];
        }
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type {
    NSLog(@"pushRegistry:didInvalidatePushTokenForType:");

    if ([type isEqualToString:PKPushTypeVoIP]) {
        if (self.pushKitUpdateDelegate && [self.pushKitUpdateDelegate respondsToSelector:@selector(credentialsInvalidated)]) {
            [self.pushKitUpdateDelegate credentialsInvalidated];
        }
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry
didReceiveIncomingPushWithPayload:(PKPushPayload *)payload
             forType:(NSString *)type {
    NSLog(@"pushRegistry:didReceiveIncomingPushWithPayload:forType:");
    
    if (self.pushKitUpdateDelegate &&
        [self.pushKitUpdateDelegate respondsToSelector:@selector(incomingPushReceived:withCompletionHandler:)]) {
        [self.pushKitUpdateDelegate incomingPushReceived:payload withCompletionHandler:nil];
    }
}

/**
 * This delegate method is available on iOS 11 and above. Call the completion handler once the
 * notification payload is passed to the `TwilioVoice.handleNotification()` method.
 */
- (void)pushRegistry:(PKPushRegistry *)registry
didReceiveIncomingPushWithPayload:(PKPushPayload *)payload
             forType:(PKPushType)type
withCompletionHandler:(void (^)(void))completion {
    NSLog(@"pushRegistry:didReceiveIncomingPushWithPayload:forType:withCompletionHandler:");
    
    if (self.pushKitUpdateDelegate &&
        [self.pushKitUpdateDelegate respondsToSelector:@selector(incomingPushReceived:withCompletionHandler:)]) {
        [self.pushKitUpdateDelegate incomingPushReceived:payload withCompletionHandler:completion];
    }

    if ([[NSProcessInfo processInfo] operatingSystemVersion].majorVersion >= 13) {
        /*
         * The Voice SDK processes the call notification and returns the call invite synchronously. Report the incoming call to
         * CallKit and fulfill the completion before exiting this callback method.
         */
        completion();
    }
}

@end
