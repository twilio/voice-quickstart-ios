// IncomingCallView.swift
// Twilio Voice Quickstart - SwiftUI
//
// Copyright © Twilio, Inc. All rights reserved.

import SwiftUI

struct IncomingCallView: View {
    @EnvironmentObject var callManager: CallManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "phone.arrow.down.left")
                    .font(.system(size: 44))
                    .foregroundColor(.green)

                Text(callManager.incomingCaller ?? "Unknown")
                    .font(.title2.weight(.semibold))

                Text("Incoming Call")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 60) {
                // Decline
                Button {
                    callManager.declineIncomingCall()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 72, height: 72)
                            .background(Color.red)
                            .clipShape(Circle())

                        Text("Decline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Accept
                Button {
                    callManager.acceptIncomingCall()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 72, height: 72)
                            .background(Color.green)
                            .clipShape(Circle())

                        Text("Accept")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, 80)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
