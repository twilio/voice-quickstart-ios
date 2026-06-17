//
//  CallManager.swift
//  Twilio Voice Quickstart - LiveCommunicationKit
//
//  Copyright © Twilio, Inc. All rights reserved.
//

import Foundation
import UIKit
import TwilioVoice
import PushKit
import AVFoundation

let accessToken = "PASTE_YOUR_ACCESS_TOKEN_HERE"
let twimlParamTo = "to"

enum CallState {
    case idle
    case connecting
    case ringing
    case connected
    case reconnecting
    case disconnected
}

/// Receives high-level call events from CallManager so the UI layer can update.
/// All callbacks are dispatched on the main queue.
protocol CallManagerDelegate: AnyObject {
    func callManager(_ manager: CallManager, didChangeState state: CallState)
}

/// Owns Twilio Voice call state, implements NotificationDelegate + CallDelegate, and routes
/// requests to LiveCommunicationKitManager so the system call UI stays in sync.
final class CallManager: NSObject {

    static let shared = CallManager()

    weak var delegate: CallManagerDelegate?

    let audioDevice = DefaultAudioDevice()

    private(set) var activeCall: Call? = nil
    private(set) var activeCallInvite: CallInvite? = nil

    /// Set synchronously inside `callInviteReceived` so the push handler can await the LCK
    /// report on the very next line after `TwilioVoiceSDK.handleNotification` returns.
    fileprivate var pendingIncomingReport: (from: String, uuid: UUID)? = nil

    private var conversationCompletionCallback: ((Bool) -> Void)? = nil
    var userInitiatedDisconnect: Bool = false

    /// When `<Dial answerOnBridge="true">` is used, the caller hears no ringback while the call is
    /// awaiting accept on the callee side. Flip this to play a custom ringback in the gap.
    var playCustomRingback = false
    private var ringtonePlayer: AVAudioPlayer? = nil

    private var pendingOutgoingRecipient: String? = nil

    private override init() {
        super.init()
        // Must be set before connecting/accepting any Twilio Call.
        TwilioVoiceSDK.audioDevice = audioDevice
    }

    // MARK: Public — outgoing

    /// Called by the UI to start a new outgoing call. Routes through ConversationManager so the
    /// system call UI is shown; the actual Twilio connect happens in `performVoiceCall(uuid:_:)`
    /// when LiveCommunicationKit performs the StartConversationAction.
    func startCall(to recipient: String) {
        pendingOutgoingRecipient = recipient.isEmpty ? nil : recipient
        let handle = recipient.isEmpty ? "Voice Bot" : recipient
        LiveCommunicationKitManager.shared.startConversation(uuid: UUID(), handle: handle)
    }

    func endActiveCall() {
        guard let call = getActiveCall(), let uuid = call.uuid else { return }
        userInitiatedDisconnect = true
        LiveCommunicationKitManager.shared.endConversation(uuid: uuid)
    }

    // MARK: Public — mute / hold

    func toggleMute(_ muted: Bool) {
        guard let call = getActiveCall(), let uuid = call.uuid else { return }
        LiveCommunicationKitManager.shared.setMuted(uuid: uuid, muted: muted)
    }

    func toggleHold(_ onHold: Bool) {
        guard let call = getActiveCall(), let uuid = call.uuid else { return }
        LiveCommunicationKitManager.shared.setPaused(uuid: uuid, paused: onHold)
    }

    func toggleAudioRoute(toSpeaker: Bool) {
        // The Voice SDK sets the audio mode to "VoiceChat" so the default route is the receiver.
        audioDevice.block = {
            do {
                if toSpeaker {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
                } else {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(.none)
                }
            } catch {
                NSLog(error.localizedDescription)
            }
        }
        audioDevice.block()
    }

    func getActiveCall() -> Call? {
        if let activeCall = activeCall {
            return activeCall
        }
        
        return nil
    }

    // MARK: Action handlers (called by LiveCommunicationKitManager)

    func performVoiceCall(uuid: UUID, completion: @escaping (Bool) -> Void) {
        let connectOptions = ConnectOptions(accessToken: accessToken) { [weak self] builder in
            builder.params = [twimlParamTo: self?.pendingOutgoingRecipient ?? ""]
            builder.uuid = uuid
        }
        let call = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
        activeCall = call
        conversationCompletionCallback = completion
        publish(state: .connecting)
    }

    func performAnswerVoiceCall(uuid: UUID, completion: @escaping (Bool) -> Void) {
        guard let callInvite = activeCallInvite else {
            NSLog("No active CallInvite")
            completion(false)
            return
        }
        let acceptOptions = AcceptOptions(callInvite: callInvite) { builder in
            builder.uuid = callInvite.uuid
        }
        let call = callInvite.accept(options: acceptOptions, delegate: self)
        activeCall = call
        conversationCompletionCallback = completion
        activeCallInvite = nil
    }

    func performEndCall(uuid: UUID) {
        if let invite = activeCallInvite {
            invite.reject()
        } else if let call = activeCall {
            call.disconnect()
        } else {
            NSLog("Unknown UUID to perform end action with")
        }
    }

    @discardableResult
    func setCallMuted(uuid: UUID, muted: Bool) -> Bool {
        guard let call = activeCall, call.uuid == uuid else { return false }
        call.isMuted = muted
        return true
    }

    @discardableResult
    func setCallOnHold(uuid: UUID, onHold: Bool) -> Bool {
        guard let call = activeCall, call.uuid == uuid else { return false }
        call.isOnHold = onHold
        // Workaround: didActivate isn't called when unholding after a remote-ended interrupting call.
        // https://developer.apple.com/forums/thread/694836
        if !onHold {
            audioDevice.isEnabled = true
            activeCall = call
        }
        return true
    }

    @discardableResult
    func sendDigits(uuid: UUID, digits: String) -> Bool {
        guard let call = activeCall, call.uuid == uuid else { return false }
        call.sendDigits(digits)
        return true
    }

    // MARK: Helpers

    private func publish(state: CallState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.callManager(self, didChangeState: state)
        }
    }

    private func playRingback() {
        guard let path = Bundle.main.path(forResource: "ringtone", ofType: "wav") else { return }
        do {
            ringtonePlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            ringtonePlayer?.numberOfLoops = -1
            ringtonePlayer?.volume = 1.0
            ringtonePlayer?.play()
        } catch {
            NSLog("Failed to initialize audio player")
        }
    }

    private func stopRingback() {
        guard let player = ringtonePlayer, player.isPlaying else { return }
        player.stop()
    }
}


// MARK: - PushKit forwarding (called by PushKitManager)

extension CallManager {

    func credentialsUpdated(credentials: PKPushCredentials) {
        let cachedDeviceToken = credentials.token
        TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: cachedDeviceToken) { error in
            if let error = error {
                NSLog("An error occurred while registering: \(error.localizedDescription)")
            } else {
                NSLog("Successfully registered for VoIP push notifications.")
            }
        }
    }

    /// Processes an incoming VoIP push and reports the resulting CallInvite to LiveCommunicationKit.
    ///
    /// The PushKit contract requires that the call be surfaced to the system BEFORE the push
    /// completion fires; otherwise iOS terminates the app. `reportNewIncomingConversation` is
    /// `async`, so the push handler must `await` this method (and only then invoke its own
    /// `completion()` callback).
    func incomingPushReceived(payload: PKPushPayload) async {
        // Twilio's `handleNotification` is synchronous: by the time it returns, our
        // `callInviteReceived` delegate method has already fired and stashed the invite (and the
        // caller string) on `pendingIncomingReport`. We then await the LCK report on that.
        TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)

        guard let report = pendingIncomingReport else { return }
        pendingIncomingReport = nil
        await LiveCommunicationKitManager.shared.reportIncomingConversation(from: report.from, uuid: report.uuid)
    }
}


// MARK: - NotificationDelegate

extension CallManager: NotificationDelegate {

    func callInviteReceived(callInvite: CallInvite) {
        NSLog("callInviteReceived:")
        
        activeCallInvite = callInvite

        let callerInfo: TVOCallerInfo = callInvite.callerInfo
        if let verified: NSNumber = callerInfo.verified, verified.boolValue {
            NSLog("Call invite received from verified caller number!")
        }

        let from = (callInvite.from ?? "Voice Bot").replacingOccurrences(of: "client:", with: "")
        // Hand off to the push handler — it awaits the LCK report before calling PushKit completion.
        pendingIncomingReport = (from: from, uuid: callInvite.uuid)
    }

    func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        NSLog("cancelledCallInviteCanceled:error: \(error.localizedDescription)")

        guard let callInvite = activeCallInvite  else {
            NSLog("No pending call invite")
            return
        }

        LiveCommunicationKitManager.shared.endConversation(uuid: callInvite.uuid)
        activeCallInvite = nil
    }
}


// MARK: - CallDelegate

extension CallManager: CallDelegate {

    func callDidStartRinging(call: Call) {
        NSLog("callDidStartRinging:")
        publish(state: .ringing)
        if playCustomRingback { playRingback() }
    }

    func callDidConnect(call: Call) {
        NSLog("callDidConnect:")
        if playCustomRingback { stopRingback() }

        conversationCompletionCallback?(true)
        conversationCompletionCallback = nil

        LiveCommunicationKitManager.shared.reportConnected(uuid: call.uuid!)

        toggleAudioRoute(toSpeaker: true)
        publish(state: .connected)
    }

    func callIsReconnecting(call: Call, error: Error) {
        NSLog("call:isReconnectingWithError:")
        publish(state: .reconnecting)
    }

    func callDidReconnect(call: Call) {
        NSLog("callDidReconnect:")
        publish(state: .connected)
    }

    func callDidFailToConnect(call: Call, error: Error) {
        NSLog("Call failed to connect: \(error.localizedDescription)")

        conversationCompletionCallback?(false)
        conversationCompletionCallback = nil

        if let uuid = call.uuid {
            LiveCommunicationKitManager.shared.reportEnded(uuid: uuid, failed: true)
        }

        callDisconnected(call: call)
    }

    func callDidDisconnect(call: Call, error: Error?) {
        if let error = error {
            NSLog("Call failed: \(error.localizedDescription)")
        } else {
            NSLog("Call disconnected")
        }

        if !userInitiatedDisconnect, let uuid = call.uuid {
            LiveCommunicationKitManager.shared.reportEnded(uuid: uuid, failed: error != nil)
        }

        callDisconnected(call: call)
    }

    private func callDisconnected(call: Call) {
        if call == activeCall {
            activeCall = nil
        }

        userInitiatedDisconnect = false
        if playCustomRingback { stopRingback() }

        publish(state: .idle)
    }
}
