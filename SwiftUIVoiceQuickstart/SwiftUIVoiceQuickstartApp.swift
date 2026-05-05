// SwiftUIVoiceQuickstartApp.swift
// Twilio Voice Quickstart - SwiftUI
//
// Copyright © 2024 Twilio, Inc. All rights reserved.

import SwiftUI

@main
struct SwiftUIVoiceQuickstartApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(CallManager.shared)
        }
    }
}
