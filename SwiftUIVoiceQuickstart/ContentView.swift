//
//  ContentView.swift
//  SwiftUIVoiceQuickstart
//
//  Created by Bobie Chen on 9/22/21.
//

import SwiftUI

let kAccessToken = ""

struct ContentView: View {
    @State private var outgoingTo = ""
    
    var callControl = CallControl(accessToken: kAccessToken)

    var body: some View {
        VStack(alignment: .center) {
            TextField("To", text: $outgoingTo)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
                .padding()
            Button("Call") {
                //role: "Call", action: makeCall
                callControl.makeCall(to: "\(outgoingTo)")
            }
        }
    }
    
    func makeCall() {
        print("To: \(outgoingTo)")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
