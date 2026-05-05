// ContentView.swift
// Twilio Voice Quickstart - SwiftUI
//
// Copyright © 2024 Twilio, Inc. All rights reserved.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var callManager: CallManager

    var body: some View {
        Group {
            if callManager.callState == .idle {
                DialerView()
            } else {
                InCallView()
            }
        }
        .animation(.easeInOut, value: callManager.callState == .idle)
    }
}
