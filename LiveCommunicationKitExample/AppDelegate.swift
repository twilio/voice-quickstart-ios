//
//  AppDelegate.swift
//  Twilio Voice Quickstart - LiveCommunicationKit
//
//  Copyright © Twilio, Inc. All rights reserved.
//

import UIKit
import TwilioVoice
import PushKit

protocol PushKitEventDelegate: AnyObject {
    func credentialsUpdated(credentials: PKPushCredentials) -> Void
    func incomingPushReceived(payload: PKPushPayload, completion: @escaping () -> Void) -> Void
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate {

    var window: UIWindow?
    var pushKitEventDelegate: PushKitEventDelegate?
    var voipRegistry = PKPushRegistry.init(queue: DispatchQueue.main)

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NSLog("Twilio Voice Version: %@", TwilioVoiceSDK.sdkVersion())

        let viewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController as? ViewController
        self.pushKitEventDelegate = viewController
        /*
         * Your app must initialize PKPushRegistry with PushKit push type VoIP at the launch time. As mentioned in the
         * [PushKit guidelines](https://developer.apple.com/documentation/pushkit/supporting_pushkit_notifications_in_your_app),
         * the system can't deliver push notifications to your app until you create a PKPushRegistry object for
         * VoIP push type and set the delegate. If your app delays the initialization of PKPushRegistry, your app may receive
         * outdated PushKit push notifications, and if your app decides not to report the received outdated push notifications
         * to LiveCommunicationKit, iOS may terminate your app.
         */
        initializePushKit()

        return true
    }

    func initializePushKit() {
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
    }

    // MARK: PKPushRegistryDelegate

    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        NSLog("pushRegistry:didUpdatePushCredentials:forType:")

        if let delegate = self.pushKitEventDelegate {
            delegate.credentialsUpdated(credentials: credentials)
        }
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        NSLog("pushRegistry:didInvalidatePushTokenForType:")
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:completion:")

        if let delegate = self.pushKitEventDelegate {
            delegate.incomingPushReceived(payload: payload, completion: completion)
        }

        /*
         * The Voice SDK processes the call notification and returns the call invite synchronously. Report the incoming
         * call to LiveCommunicationKit and fulfill the completion before exiting this callback method.
         */
        completion()
    }
}
