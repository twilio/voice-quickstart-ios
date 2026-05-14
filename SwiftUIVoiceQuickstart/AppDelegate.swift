// AppDelegate.swift
// Twilio Voice Quickstart - SwiftUI
//
// Copyright © Twilio, Inc. All rights reserved.

import UIKit

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        /*
         * Must initialize PKPushRegistry at launch. Delaying this can cause iOS to drop
         * VoIP pushes and terminate the app for not reporting them to CallKit.
         */
        PushKitManager.shared.initialize()
        return true
    }
}
