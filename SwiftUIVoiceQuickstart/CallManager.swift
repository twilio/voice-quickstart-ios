// CallManager.swift
// Twilio Voice Quickstart - SwiftUI
//
// Copyright © Twilio, Inc. All rights reserved.

import Foundation
import UIKit
import TwilioVoice
import PushKit
import CallKit
import AVFoundation
import Combine

let accessToken = <#PASTE YOUR ACCESS TOKEN HERE#>
let twimlParamTo = "to"

enum CallState {
    case idle
    case connecting
    case ringing
    case connected
    case reconnecting
    case disconnected
}

/// Observable call state shared across all SwiftUI views.
/// All delegate callbacks arrive on the main queue (PKPushRegistry queue:.main,
/// TwilioVoice delegateQueue:nil, CXProvider queue:nil), so @Published mutations
/// are always on main even without the @MainActor class annotation.
final class CallManager: NSObject, ObservableObject {

    static let shared = CallManager()

    // MARK: Published state

    @Published var callState: CallState = .idle
    @Published var isMuted: Bool = false
    @Published var isOnHold: Bool = false
    @Published var isSpeakerOn: Bool = false
    @Published var qualityWarning: String? = nil
    @Published var activeCallUUID: UUID? = nil

    // MARK: Internal

    let audioDevice = DefaultAudioDevice()
    private var activeCallInvites: [String: CallInvite] = [:]
    private var activeCalls: [String: Call] = [:]
    private var activeCall: Call? = nil
    private var callKitCompletionCallback: ((Bool) -> Void)? = nil
    var userInitiatedDisconnect: Bool = false
    private var incomingPushCompletionCallback: (() -> Void)? = nil

    var playCustomRingback = false
    private var ringtonePlayer: AVAudioPlayer? = nil

    private override init() {
        super.init()
        TwilioVoiceSDK.audioDevice = audioDevice
    }

    // MARK: Outgoing call

    var pendingOutgoingRecipient: String? = nil

    func initiateCall(to recipient: String) {
        pendingOutgoingRecipient = recipient.isEmpty ? nil : recipient
        let handle = recipient.isEmpty ? "Voice Bot" : recipient
        let uuid = UUID()
        CallKitManager.shared.startCall(uuid: uuid, handle: handle)
    }

    func performVoiceCall(uuid: UUID, completion: @escaping (Bool) -> Void) {
        let connectOptions = ConnectOptions(accessToken: accessToken) { [weak self] builder in
            guard let self else { return }
            builder.params = [twimlParamTo: self.pendingOutgoingRecipient ?? ""]
            builder.uuid = uuid
        }
        let call = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
        activeCall = call
        if let callUUID = call.uuid {
            activeCalls[callUUID.uuidString] = call
            activeCallUUID = callUUID
        }
        callKitCompletionCallback = completion
        callState = .connecting
    }

    // MARK: Hang up

    func disconnect() {
        guard let call = getActiveCall() else { return }
        userInitiatedDisconnect = true
        CallKitManager.shared.endCall(uuid: call.uuid!)
    }

    // MARK: Hold / Mute / Speaker

    func toggleHold() {
        guard let call = getActiveCall(), let uuid = call.uuid else { return }
        let newHold = !isOnHold
        CallKitManager.shared.setHeld(uuid: uuid, onHold: newHold)
    }

    func toggleMute() {
        guard let call = getActiveCall(), let uuid = call.uuid else { return }
        CallKitManager.shared.setMuted(uuid: uuid, muted: !isMuted)
    }

    func toggleSpeaker() {
        isSpeakerOn.toggle()
        toggleAudioRoute(toSpeaker: isSpeakerOn)
    }

    private func toggleAudioRoute(toSpeaker: Bool) {
        audioDevice.block = {
            do {
                if toSpeaker {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                } else {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                }
            } catch {
                NSLog("Audio route error: \(error.localizedDescription)")
            }
        }
        audioDevice.block()
    }

    // MARK: Internal helpers

    private func getActiveCall() -> Call? {
        activeCall ?? activeCalls.values.first
    }

    // MARK: CallKit action handlers (called by CallKitManager)

    func performEndCall(uuid: UUID) {
        if let invite = activeCallInvites[uuid.uuidString] {
            invite.reject()
            activeCallInvites.removeValue(forKey: uuid.uuidString)
        } else if let call = activeCalls[uuid.uuidString] {
            call.disconnect()
        }
    }

    @discardableResult
    func setCallOnHold(uuid: UUID, onHold: Bool) -> Bool {
        guard let call = activeCalls[uuid.uuidString] else { return false }
        call.isOnHold = onHold
        if !onHold {
            audioDevice.isEnabled = true
            activeCall = call
        }
        isOnHold = onHold
        return true
    }

    @discardableResult
    func setCallMuted(uuid: UUID, muted: Bool) -> Bool {
        guard let call = activeCalls[uuid.uuidString] else { return false }
        call.isMuted = muted
        isMuted = muted
        return true
    }

    @discardableResult
    func sendDigits(uuid: UUID, digits: String) -> Bool {
        guard let call = activeCalls[uuid.uuidString] else { return false }
        call.sendDigits(digits)
        return true
    }

    func performAnswerVoiceCall(uuid: UUID, completion: @escaping (Bool) -> Void) {
        guard let callInvite = activeCallInvites[uuid.uuidString] else {
            NSLog("No CallInvite for UUID")
            return
        }
        let acceptOptions = AcceptOptions(callInvite: callInvite) { builder in
            builder.uuid = callInvite.uuid
        }
        let call = callInvite.accept(options: acceptOptions, delegate: self)
        activeCall = call
        if let callUUID = call.uuid {
            activeCalls[callUUID.uuidString] = call
            activeCallUUID = callUUID
        }
        callKitCompletionCallback = completion
        activeCallInvites.removeValue(forKey: uuid.uuidString)

        if #unavailable(iOS 13) {
            incomingPushHandled()
        }
    }

    // MARK: Ringback

    private func playRingback() {
        guard let path = Bundle.main.path(forResource: "ringtone", ofType: "wav") else { return }
        do {
            ringtonePlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            ringtonePlayer?.numberOfLoops = -1
            ringtonePlayer?.volume = 1.0
            ringtonePlayer?.play()
        } catch {
            NSLog("Ringtone error: \(error.localizedDescription)")
        }
    }

    private func stopRingback() {
        guard let player = ringtonePlayer, player.isPlaying else { return }
        player.stop()
    }

    private func incomingPushHandled() {
        guard let cb = incomingPushCompletionCallback else { return }
        incomingPushCompletionCallback = nil
        cb()
    }
}

// MARK: - PushKit forwarding

extension CallManager {

    func credentialsUpdated(credentials: PKPushCredentials) {
        let token = credentials.token
        TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: token) { error in
            if let error = error {
                NSLog("Registration error: \(error.localizedDescription)")
            } else {
                NSLog("Successfully registered for VoIP push.")
            }
        }
    }

    func incomingPushReceived(payload: PKPushPayload, completion: @escaping () -> Void) {
        TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
    }
}

// MARK: - NotificationDelegate

extension CallManager: NotificationDelegate {

    func callInviteReceived(callInvite: CallInvite) {
        NSLog("callInviteReceived:")

        let from = (callInvite.from ?? "Voice Bot").replacingOccurrences(of: "client:", with: "")
        CallKitManager.shared.reportIncomingCall(from: from, uuid: callInvite.uuid)
        activeCallInvites[callInvite.uuid.uuidString] = callInvite
    }

    func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        NSLog("cancelledCallInviteReceived: \(error.localizedDescription)")
        guard let invite = activeCallInvites.values.first(where: { $0.callSid == cancelledCallInvite.callSid }) else { return }
        CallKitManager.shared.endCall(uuid: invite.uuid)
        activeCallInvites.removeValue(forKey: invite.uuid.uuidString)
    }
}

// MARK: - CallDelegate

extension CallManager: CallDelegate {

    func callDidStartRinging(call: Call) {
        NSLog("callDidStartRinging:")
        callState = .ringing
        if playCustomRingback { playRingback() }
    }

    func callDidConnect(call: Call) {
        NSLog("callDidConnect:")
        if playCustomRingback { stopRingback() }
        callKitCompletionCallback?(true)
        callKitCompletionCallback = nil
        callState = .connected
        isMuted = call.isMuted
        toggleAudioRoute(toSpeaker: true)
        isSpeakerOn = true
    }

    func callIsReconnecting(call: Call, error: Error) {
        NSLog("callIsReconnecting:")
        callState = .reconnecting
    }

    func callDidReconnect(call: Call) {
        NSLog("callDidReconnect:")
        callState = .connected
    }

    func callDidFailToConnect(call: Call, error: Error) {
        NSLog("callDidFailToConnect: \(error.localizedDescription)")
        callKitCompletionCallback?(false)
        callKitCompletionCallback = nil
        CallKitManager.shared.provider.reportCall(with: call.uuid!, endedAt: Date(), reason: .failed)
        callEnded(call: call)
    }

    func callDidDisconnect(call: Call, error: Error?) {
        if !userInitiatedDisconnect {
            let reason: CXCallEndedReason = error != nil ? .failed : .remoteEnded
            CallKitManager.shared.provider.reportCall(with: call.uuid!, endedAt: Date(), reason: reason)
        }
        if let error = error {
            NSLog("Call failed: \(error.localizedDescription)")
        } else {
            NSLog("Call disconnected")
        }
        callEnded(call: call)
    }

    private func callEnded(call: Call) {
        if call == activeCall { activeCall = nil }
        activeCalls.removeValue(forKey: call.uuid!.uuidString)
        userInitiatedDisconnect = false
        if playCustomRingback { stopRingback() }
        if activeCalls.isEmpty {
            callState = .idle
            activeCallUUID = nil
            isMuted = false
            isOnHold = false
            isSpeakerOn = false
        }
    }

    func callDidReceiveQualityWarnings(call: Call,
                                       currentWarnings: Set<NSNumber>,
                                       previousWarnings: Set<NSNumber>) {
        let intersection = currentWarnings.intersection(previousWarnings)
        let newWarnings = currentWarnings.subtracting(intersection)
        let clearedWarnings = previousWarnings.subtracting(intersection)

        if !newWarnings.isEmpty {
            qualityWarning = "Warnings: " + newWarnings.map { warningString(Call.QualityWarning(rawValue: $0.uintValue)!) }.joined(separator: ", ")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.qualityWarning = nil }
        }
        if !clearedWarnings.isEmpty {
            NSLog("Cleared warnings: \(clearedWarnings)")
        }
    }

    private func warningString(_ w: Call.QualityWarning) -> String {
        switch w {
        case .highRtt: return "high-rtt"
        case .highJitter: return "high-jitter"
        case .highPacketsLostFraction: return "high-packets-lost-fraction"
        case .lowMos: return "low-mos"
        case .constantAudioInputLevel: return "constant-audio-input-level"
        case .constantAudioOutputLevel: return "constant-audio-output-level"
        default: return "unknown"
        }
    }
}
