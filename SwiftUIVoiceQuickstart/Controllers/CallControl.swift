//
//  CallControl.swift
//  SwiftUIVoiceQuickstart
//
//  Copyright © 2024 Twilio, Inc. All rights reserved.
//

import Foundation
import TwilioVoice

class CallControl: NSObject {
    
    private var voiceAccessToken: String?
    
    init(accessToken: String) {
        voiceAccessToken = accessToken
        super.init()
    }
    
    func makeCall(to: String) {
        print("CallControl::makeCall")
    }
}
