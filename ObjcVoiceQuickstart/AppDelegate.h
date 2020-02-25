//
//  AppDelegate.h
//  Twilio Voice with Quickstart - Objective-C
//
//  Copyright © 2016 Twilio, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@import PushKit;

@protocol PushKitEventDelegate <NSObject>

- (void)credentialsUpdated:(PKPushCredentials *)credentials;
- (void)credentialsInvalidated;
- (void)incomingPushReceived:(PKPushPayload *)payload withCompletionHandler:(void (^)(void))completion;

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@end

