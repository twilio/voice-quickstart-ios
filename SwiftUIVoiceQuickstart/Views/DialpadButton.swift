//
//  DialpadButton.swift
//  SwiftUIVoiceQuickstart
//
//  Copyright © 2024 Twilio, Inc. All rights reserved.
//

import SwiftUI

let kButtonSize : CGFloat = 80

struct DialpadButton: View {
    let text: String
    let action: () -> Void
    
    init(text: String, action: @escaping () -> Void = { }) {
        self.text = text
        self.action = action
    }

    var body: some View {
        Button(action: {
            action()
        }) {
            Text(self.text)
                .frame(width: kButtonSize, height: kButtonSize)
                .foregroundColor(Color.blue)
                .overlay(
                    Circle()
                        .stroke(Color.blue, lineWidth: 1)
                )
        }
    }
}
