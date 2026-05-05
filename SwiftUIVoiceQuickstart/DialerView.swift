// DialerView.swift
// Twilio Voice Quickstart - SwiftUI
//
// Copyright © Twilio, Inc. All rights reserved.

import SwiftUI

struct DialerView: View {
    @EnvironmentObject var callManager: CallManager
    @State private var dialedNumber: String = ""
    @FocusState private var identityFieldFocused: Bool

    private let dialPadKeys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["*", "0", "#"]
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                // Display / identity field
                VStack(spacing: 8) {
                    Text("Enter number or client ID")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(dialedNumber.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal)

                    // Text field for client identity
                    TextField("Or type a client identity…", text: $dialedNumber)
                        .focused($identityFieldFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .multilineTextAlignment(.center)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                        .opacity(identityFieldFocused ? 1 : 0.6)

                    if !dialedNumber.isEmpty {
                        Button {
                            dialedNumber.remove(at: dialedNumber.index(before: dialedNumber.endIndex))
                        } label: {
                            Image(systemName: "delete.left")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom, 8)

                Divider().padding(.horizontal)

                // Dial pad
                VStack(spacing: 12) {
                    ForEach(dialPadKeys, id: \.self) { row in
                        HStack(spacing: 20) {
                            ForEach(row, id: \.self) { key in
                                DialPadButton(key: key) {
                                    identityFieldFocused = false
                                    dialedNumber += key
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Call button
                Button {
                    identityFieldFocused = false
                    callManager.initiateCall(to: dialedNumber)
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .frame(width: 72, height: 72)
                        .background(Color.green)
                        .clipShape(Circle())
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("SwiftUI Quickstart")
            .navigationBarTitleDisplayMode(.inline)
            .contentShape(Rectangle())
            .onTapGesture { identityFieldFocused = false }
        }
    }
}

// MARK: - Dial Pad Button

struct DialPadButton: View {
    let key: String
    let action: () -> Void

    private let subLabel: [String: String] = [
        "2": "ABC", "3": "DEF", "4": "GHI", "5": "JKL", "6": "MNO",
        "7": "PQRS", "8": "TUV", "9": "WXYZ", "0": "+", "1": "", "*": "", "#": ""
    ]

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(key)
                    .font(.system(size: 30, weight: .light))
                if let sub = subLabel[key], !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(2)
                }
            }
            .frame(width: 80, height: 80)
            .background(Color(.systemGray5))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
