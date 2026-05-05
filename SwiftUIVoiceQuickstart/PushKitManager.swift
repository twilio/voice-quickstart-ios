// PushKitManager.swift
// Twilio Voice Quickstart - SwiftUI
//
// Copyright © 2024 Twilio, Inc. All rights reserved.

import UIKit
import PushKit
import TwilioVoice

let kRegistrationTTLInDays = 365
let kCachedDeviceToken = "CachedDeviceToken"
let kCachedBindingDate = "CachedBindingDate"

/// Owns the PKPushRegistry and forwards VoIP push events to CallManager.
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
        CallManager.shared.credentialsInvalidated()
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType) {
        NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:")
        CallManager.shared.incomingPushReceived(payload: payload)
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {
        NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:completion:")
        CallManager.shared.incomingPushReceived(payload: payload, completion: completion)

        if let version = Float(UIDevice.current.systemVersion), version >= 13.0 {
            completion()
        }
    }
}
