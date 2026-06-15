//
//  LiveCommunicationKitManager.swift
//  Twilio Voice Quickstart - LiveCommunicationKit
//
//  Copyright © Twilio, Inc. All rights reserved.
//

import LiveCommunicationKit
import AVFoundation

/// Wraps all ConversationManager interactions and routes LiveCommunicationKit actions to CallManager.
///
/// LiveCommunicationKit is the iOS 17.4+ alternative to CallKit. A single ConversationManager
/// replaces the CXProvider + CXCallController pair: it both surfaces the system call UI and
/// accepts requests via `manager.perform([action])`.
@available(iOS 17.4, *)
final class LiveCommunicationKitManager: NSObject {

    static let shared = LiveCommunicationKitManager()

    let manager: ConversationManager

    private override init() {
        let configuration = ConversationManager.Configuration(
            ringtoneName: nil,
            iconTemplateImageData: nil,
            maximumConversationGroups: 2,
            maximumConversationsPerConversationGroup: 1,
            includesConversationInRecents: true,
            supportsVideo: false,
            supportedHandleTypes: [.generic]
        )
        manager = ConversationManager(configuration: configuration)
        super.init()
        manager.delegate = self
    }

    deinit {
        manager.invalidate()
    }

    // MARK: Outgoing conversation

    func startConversation(uuid: UUID, handle: String) {
        let lckHandle = Handle(type: .generic, value: handle, displayName: handle)
        let action = StartConversationAction(conversationUUID: uuid, handles: [lckHandle], isVideo: false)
        Task {
            do {
                try await manager.perform([action])
                NSLog("StartConversationAction request successful")
            } catch {
                NSLog("StartConversationAction request failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Incoming conversation

    func reportIncomingConversation(from: String, uuid: UUID) {
        let lckHandle = Handle(type: .generic, value: from, displayName: from)
        let update = Conversation.Update(
            localMember: nil,
            members: [lckHandle],
            activeRemoteMembers: [lckHandle],
            capabilities: []
        )
        Task {
            do {
                try await manager.reportNewIncomingConversation(uuid: uuid, update: update)
                NSLog("Incoming conversation successfully reported.")
            } catch {
                NSLog("Failed to report incoming conversation: \(error.localizedDescription)")
            }
        }
    }

    // MARK: End / Mute / Pause

    func endConversation(uuid: UUID) {
        let action = EndConversationAction(conversationUUID: uuid)
        Task {
            do { try await manager.perform([action]) }
            catch { NSLog("EndConversationAction failed: \(error.localizedDescription)") }
        }
    }

    func setMuted(uuid: UUID, muted: Bool) {
        let action = MuteConversationAction(conversationUUID: uuid, isMuted: muted)
        Task {
            do { try await manager.perform([action]) }
            catch { NSLog("MuteConversationAction failed: \(error.localizedDescription)") }
        }
    }

    func setPaused(uuid: UUID, paused: Bool) {
        let action = PauseConversationAction(conversationUUID: uuid, isPaused: paused)
        Task {
            do { try await manager.perform([action]) }
            catch { NSLog("PauseConversationAction failed: \(error.localizedDescription)") }
        }
    }

    // MARK: Lifecycle reporting (CallKit equivalents of reportOutgoingCall / reportCall(endedAt:))

    func reportStartedConnecting(uuid: UUID) {
        guard let conversation = manager.conversations.first(where: { $0.uuid == uuid }) else { return }
        manager.reportConversationEvent(.conversationStartedConnecting(Date()), for: conversation)
    }

    func reportConnected(uuid: UUID) {
        guard let conversation = manager.conversations.first(where: { $0.uuid == uuid }) else { return }
        manager.reportConversationEvent(.conversationConnected(Date()), for: conversation)
    }

    func reportEnded(uuid: UUID, failed: Bool) {
        guard let conversation = manager.conversations.first(where: { $0.uuid == uuid }) else { return }
        let reason: Conversation.EndedReason = failed ? .failed : .remoteEnded
        manager.reportConversationEvent(.conversationEnded(Date(), reason), for: conversation)
    }
}


// MARK: - ConversationManagerDelegate

@available(iOS 17.4, *)
extension LiveCommunicationKitManager: ConversationManagerDelegate {

    func conversationManagerDidBegin(_ manager: ConversationManager) {
        NSLog("conversationManagerDidBegin")
    }

    func conversationManagerDidReset(_ manager: ConversationManager) {
        NSLog("conversationManagerDidReset")
        CallManager.shared.audioDevice.isEnabled = false
    }

    func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession) {
        NSLog("conversationManager:didActivateAudioSession:")
        CallManager.shared.audioDevice.isEnabled = true
    }

    func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession) {
        NSLog("conversationManager:didDeactivateAudioSession:")
        CallManager.shared.audioDevice.isEnabled = false
    }

    func conversationManager(_ manager: ConversationManager, conversationChanged conversation: Conversation) {
        NSLog("conversationManager:conversationChanged: state=\(conversation.state)")
    }

    func conversationManager(_ manager: ConversationManager, timedOutPerforming action: ConversationAction) {
        NSLog("conversationManager:timedOutPerformingAction: \(type(of: action))")
    }

    /// Unlike CallKit, LiveCommunicationKit dispatches every action through a single callback.
    /// We switch on the concrete subclass to dispatch into CallManager's per-action handlers.
    func conversationManager(_ manager: ConversationManager, perform action: ConversationAction) {
        switch action {
        case let action as StartConversationAction:
            NSLog("conversationManager:perform:StartConversationAction")
            reportStartedConnecting(uuid: action.conversationUUID)
            CallManager.shared.performVoiceCall(uuid: action.conversationUUID) { success in
                if success {
                    action.fulfill(dateStarted: Date())
                }
            }

        case let action as JoinConversationAction:
            NSLog("conversationManager:perform:JoinConversationAction")
            CallManager.shared.performAnswerVoiceCall(uuid: action.conversationUUID) { success in
                if success {
                    action.fulfill(dateConnected: Date())
                }
            }

        case let action as EndConversationAction:
            NSLog("conversationManager:perform:EndConversationAction")
            CallManager.shared.performEndCall(uuid: action.conversationUUID)
            action.fulfill(dateEnded: Date())

        case let action as MuteConversationAction:
            NSLog("conversationManager:perform:MuteConversationAction")
            CallManager.shared.setCallMuted(uuid: action.conversationUUID, muted: action.isMuted)

        case let action as PauseConversationAction:
            // LiveCommunicationKit's PauseConversationAction is the equivalent of CallKit's CXSetHeldCallAction.
            NSLog("conversationManager:perform:PauseConversationAction")
            CallManager.shared.setCallOnHold(uuid: action.conversationUUID, onHold: action.isPaused)

        case let action as PlayToneAction:
            NSLog("conversationManager:perform:PlayToneAction")
            CallManager.shared.sendDigits(uuid: action.conversationUUID, digits: action.digits)

        default:
            NSLog("Unhandled action: \(type(of: action))")
        }
    }
}
