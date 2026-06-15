//
//  AppDelegate.swift
//  Twilio Voice Quickstart - LiveCommunicationKit
//
//  Copyright © Twilio, Inc. All rights reserved.
//

import UIKit
import TwilioVoice

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NSLog("Twilio Voice Version: %@", TwilioVoiceSDK.sdkVersion())

        _ = LiveCommunicationKitManager.shared
        PushKitManager.shared.initialize()

        return true
    }
}
