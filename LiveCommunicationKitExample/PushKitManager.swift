//
//  PushKitManager.swift
//  Twilio Voice Quickstart - LiveCommunicationKit
//
//  Copyright © Twilio, Inc. All rights reserved.
//

import UIKit
import PushKit

/// Owns the PKPushRegistry and forwards VoIP push events to LiveCommunicationKitManager.
final class PushKitManager: NSObject, PKPushRegistryDelegate {

    static let shared = PushKitManager()

    private var voipRegistry: PKPushRegistry?

    private override init() {}

    func initialize() {
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        voipRegistry = registry
    }

    // MARK: PKPushRegistryDelegate

    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        NSLog("pushRegistry:didUpdatePushCredentials:forType:")
        CallManager.shared.credentialsUpdated(credentials: credentials)
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        NSLog("pushRegistry:didInvalidatePushTokenForType:")
    }

    // Use the async callback to handle and report the incoming VoIP push to LiveCommunicationKit
    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType) async {
        NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType: async")
        await CallManager.shared.incomingPushReceived(payload: payload)
    }
}
