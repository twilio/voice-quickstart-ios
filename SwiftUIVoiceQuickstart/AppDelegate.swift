// AppDelegate.swift
// Twilio Voice Quickstart - SwiftUI
//
// Copyright © 2024 Twilio, Inc. All rights reserved.

import UIKit
import TwilioVoice
import PushKit

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        NSLog("Twilio Voice Version: %@", TwilioVoiceSDK.sdkVersion())

        /*
         * Must initialize PKPushRegistry at launch. Delaying this can cause iOS to drop
         * VoIP pushes and terminate the app for not reporting them to CallKit.
         */
        PushKitManager.shared.initialize()
        return true
    }
}
