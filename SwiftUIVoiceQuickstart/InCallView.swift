// InCallView.swift
// Twilio Voice Quickstart - SwiftUI
//
// Copyright © 2024 Twilio, Inc. All rights reserved.

import SwiftUI

struct InCallView: View {
    @EnvironmentObject var callManager: CallManager

    var body: some View {
        VStack(spacing: 0) {
            // Status header
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.secondary)
                    .padding(.top, 60)

                Text(callManager.pendingOutgoingRecipient ?? "Incoming Call")
                    .font(.title2.weight(.semibold))

                Text(statusText)
                    .font(.subheadline)
                    .foregroundColor(statusColor)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))

            Spacer()

            // Quality warning toast
            if let warning = callManager.qualityWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // In-call controls grid
            VStack(spacing: 24) {
                HStack(spacing: 32) {
                    InCallActionButton(
                        icon: callManager.isMuted ? "mic.slash.fill" : "mic.fill",
                        label: "Mute",
                        isActive: callManager.isMuted,
                        activeColor: .orange
                    ) {
                        callManager.toggleMute()
                    }

                    InCallActionButton(
                        icon: callManager.isOnHold ? "pause.fill" : "play.fill",
                        label: "Hold",
                        isActive: callManager.isOnHold,
                        activeColor: .blue
                    ) {
                        callManager.toggleHold()
                    }

                    InCallActionButton(
                        icon: callManager.isSpeakerOn ? "speaker.wave.3.fill" : "speaker.fill",
                        label: "Speaker",
                        isActive: callManager.isSpeakerOn,
                        activeColor: .blue
                    ) {
                        callManager.toggleSpeaker()
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 48)

            // Hang-up button
            Button {
                callManager.disconnect()
            } label: {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .padding(.bottom, 60)
        }
        .ignoresSafeArea(edges: .top)
        .animation(.easeInOut, value: callManager.qualityWarning)
    }

    private var statusText: String {
        switch callManager.callState {
        case .idle: return ""
        case .connecting: return "Connecting…"
        case .ringing: return "Ringing…"
        case .connected: return callManager.isOnHold ? "On Hold" : "Connected"
        case .reconnecting: return "Reconnecting…"
        case .disconnected: return "Disconnected"
        }
    }

    private var statusColor: Color {
        switch callManager.callState {
        case .connected: return .green
        case .reconnecting: return .orange
        case .disconnected: return .red
        default: return .secondary
        }
    }
}

// MARK: - In-Call Action Button

struct InCallActionButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isActive ? .white : .primary)
                    .frame(width: 60, height: 60)
                    .background(isActive ? activeColor : Color(.systemGray5))
                    .clipShape(Circle())

                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
