//
//  ContentView.swift
//  SwiftUIVoiceQuickstart
//
//  Copyright © 2024 Twilio, Inc. All rights reserved.
//

import SwiftUI

let kAccessToken = ""

protocol ViewModel: ObservableObject {
    func dialpadPressed() -> String
}

struct ContentView: View {
    @State private var outgoingTo: String = ""
    
    var callControl = CallControl(accessToken: kAccessToken)

    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            Spacer()
            TextField("To", text: $outgoingTo)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
                .padding()
            Button("Call") {
                callControl.makeCall(to: "\(outgoingTo)")
            }.padding()
            
            HStack(alignment: .center) {
                DialpadButton(text: "1") {
                    digitPressed(appendDigit: "1")
                }
                DialpadButton(text: "2") {
                    digitPressed(appendDigit: "2")
                }
                DialpadButton(text: "3") {
                    digitPressed(appendDigit: "3")
                }
            }
            HStack(alignment: .center) {
                DialpadButton(text: "4") {
                    digitPressed(appendDigit: "4")
                }
                DialpadButton(text: "5") {
                    digitPressed(appendDigit: "5")
                }
                DialpadButton(text: "6") {
                    digitPressed(appendDigit: "6")
                }
            }
            HStack(alignment: .center) {
                DialpadButton(text: "7") {
                    digitPressed(appendDigit: "7")
                }
                DialpadButton(text: "8") {
                    digitPressed(appendDigit: "8")
                }
                DialpadButton(text: "9") {
                    digitPressed(appendDigit: "9")
                }
            }
            HStack(alignment: .center) {
                DialpadButton(text: "+") {
                    digitPressed(appendDigit: "+")
                }
                DialpadButton(text: "0") {
                    digitPressed(appendDigit: "0")
                }
                DialpadButton(text: "←") {
                    backspacePressed()
                }
            }
            
            Spacer()
            HStack(alignment: .center) {
                Image(.twilioLogo)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text("SwiftUI Quickstart")
            }.padding()
        }.ignoresSafeArea(.keyboard)
    }
    
    func digitPressed(appendDigit: String) {
        outgoingTo = outgoingTo + appendDigit
    }
    
    func backspacePressed() {
        guard !outgoingTo.isEmpty else { return }
        outgoingTo.remove(at: outgoingTo.index(before: outgoingTo.endIndex))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
