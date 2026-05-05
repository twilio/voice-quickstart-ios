// CallKitManager.swift
// Twilio Voice Quickstart - SwiftUI
//
// Copyright © 2024 Twilio, Inc. All rights reserved.

import CallKit
import AVFoundation

/// Wraps all CXProvider interactions and routes CallKit actions to CallManager.
final class CallKitManager: NSObject {

    static let shared = CallKitManager()

    let provider: CXProvider
    let callController = CXCallController()

    private override init() {
        let config = CXProviderConfiguration(localizedName: "Voice Quickstart")
        config.maximumCallGroups = 2
        config.maximumCallsPerCallGroup = 1
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    deinit {
        provider.invalidate()
    }

    // MARK: Outgoing call

    func startCall(uuid: UUID, handle: String) {
        let callHandle = CXHandle(type: .generic, value: handle)
        let action = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: action)

        callController.request(transaction) { error in
            if let error = error {
                NSLog("StartCallAction failed: \(error.localizedDescription)")
                return
            }
            let update = CXCallUpdate()
            update.remoteHandle = callHandle
            update.supportsDTMF = true
            update.supportsHolding = true
            update.supportsGrouping = false
            update.supportsUngrouping = false
            update.hasVideo = false
            self.provider.reportCall(with: uuid, updated: update)
        }
    }

    func endCall(uuid: UUID) {
        let transaction = CXTransaction(action: CXEndCallAction(call: uuid))
        callController.request(transaction) { error in
            if let error = error {
                NSLog("EndCallAction failed: \(error.localizedDescription)")
            }
        }
    }

    func setHeld(uuid: UUID, onHold: Bool) {
        let transaction = CXTransaction(action: CXSetHeldCallAction(call: uuid, onHold: onHold))
        callController.request(transaction) { error in
            if let error = error {
                NSLog("SetHeldCallAction failed: \(error.localizedDescription)")
            }
        }
    }

    func setMuted(uuid: UUID, muted: Bool) {
        let transaction = CXTransaction(action: CXSetMutedCallAction(call: uuid, muted: muted))
        callController.request(transaction) { error in
            if let error = error {
                NSLog("SetMutedCallAction failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Incoming call

    func reportIncomingCall(from: String, uuid: UUID) {
        let callHandle = CXHandle(type: .generic, value: from)
        let update = CXCallUpdate()
        update.remoteHandle = callHandle
        update.supportsDTMF = true
        update.supportsHolding = true
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.hasVideo = false

        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                NSLog("Failed to report incoming call: \(error.localizedDescription)")
            } else {
                NSLog("Incoming call successfully reported.")
            }
        }
    }
}

// MARK: - CXProviderDelegate

extension CallKitManager: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        NSLog("providerDidReset:")
        CallManager.shared.audioDevice.isEnabled = false
    }

    func providerDidBegin(_ provider: CXProvider) {
        NSLog("providerDidBegin")
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        NSLog("provider:didActivateAudioSession:")
        CallManager.shared.audioDevice.isEnabled = true
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        NSLog("provider:didDeactivateAudioSession:")
        CallManager.shared.audioDevice.isEnabled = false
    }

    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        NSLog("provider:timedOutPerformingAction:")
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        NSLog("provider:performStartCallAction:")
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        CallManager.shared.performVoiceCall(uuid: action.callUUID) { success in
            if success {
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
            }
        }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        NSLog("provider:performAnswerCallAction:")
        CallManager.shared.performAnswerVoiceCall(uuid: action.callUUID) { _ in }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        NSLog("provider:performEndCallAction:")
        CallManager.shared.performEndCall(uuid: action.callUUID)
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        NSLog("provider:performSetHeldAction:")
        if CallManager.shared.setCallOnHold(uuid: action.callUUID, onHold: action.isOnHold) {
            action.fulfill()
        } else {
            action.fail()
        }
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        NSLog("provider:performSetMutedAction:")
        if CallManager.shared.setCallMuted(uuid: action.callUUID, muted: action.isMuted) {
            action.fulfill()
        } else {
            action.fail()
        }
    }

    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        NSLog("provider:performPlayDTMFCallAction:")
        if CallManager.shared.sendDigits(uuid: action.callUUID, digits: action.digits) {
            action.fulfill()
        } else {
            action.fail()
        }
    }
}
