//
//  ContentView.swift
//  SwiftUIVoiceQuickstart
//
//  Created by Bobie Chen on 9/22/21.
//

import SwiftUI

struct ContentView: View {
    @State private var outgoingTo = ""

    var body: some View {
        VStack(alignment: .center) {
            TextField("To", text: $outgoingTo)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
                .padding()
            Button("Call") {
                //role: "Call", action: makeCall
                print("Call button tapped")
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
