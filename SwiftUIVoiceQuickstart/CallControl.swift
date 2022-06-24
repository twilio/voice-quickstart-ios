//
//  CallControl.swift
//  SwiftUIVoiceQuickstart
//
//  Created by Bobie Chen on 6/24/22.
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
