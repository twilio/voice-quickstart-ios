//
//  ViewController.swift
//  Twilio Voice with CallKit Quickstart - Swift
//
//  Copyright © 2016 Twilio, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import PushKit
import CallKit
import TwilioVoice

let baseURLString = <#URL TO YOUR ACCESS TOKEN SERVER#>
let accessTokenEndpoint = "/accessToken"

class ViewController: UIViewController, PKPushRegistryDelegate, TVONotificationDelegate, TVOCallDelegate, CXProviderDelegate {

    @IBOutlet weak var placeCallButton: UIButton!
    @IBOutlet weak var iconView: UIImageView!

    var deviceTokenString:String?

    var voipRegistry:PKPushRegistry

    var isSpinning: Bool
    var incomingAlertController: UIAlertController?

    var callInvite:TVOCallInvite?
    var call:TVOCall?
    var callKitCompletionCallback: ((Bool)->Swift.Void?)? = nil

    let callKitProvider:CXProvider
    let callKitCallController:CXCallController

    required init?(coder aDecoder: NSCoder) {
        isSpinning = false
        voipRegistry = PKPushRegistry.init(queue: DispatchQueue.main)
        
        TwilioVoice.logLevel = .verbose

        let configuration = CXProviderConfiguration(localizedName: "CallKit Quickstart")
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        if let callKitIcon = UIImage(named: "iconMask80") {
            configuration.iconTemplateImageData = UIImagePNGRepresentation(callKitIcon)
        }

        callKitProvider = CXProvider(configuration: configuration)
        callKitCallController = CXCallController()

        super.init(coder: aDecoder)

        callKitProvider.setDelegate(self, queue: nil)

        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
    }
    
    deinit {
        // CallKit has an odd API contract where the developer must call invalidate or the CXProvider is leaked.
        callKitProvider.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        toggleUIState(isEnabled: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func fetchAccessToken() -> String? {
        guard let accessTokenURL = URL(string: baseURLString + accessTokenEndpoint) else {
            return nil
        }

        return try? String.init(contentsOf: accessTokenURL, encoding: .utf8)
    }
    
    func toggleUIState(isEnabled: Bool) {
        placeCallButton.isEnabled = isEnabled
    }

    @IBAction func placeCall(_ sender: UIButton) {
        if (self.call != nil && self.call?.state == .connected) {
            self.call?.disconnect()
            self.toggleUIState(isEnabled: false)
        } else {
            let uuid = UUID()
            let handle = "Voice Bot"
            
            performStartCallAction(uuid: uuid, handle: handle)
        }
    }


    // MARK: PKPushRegistryDelegate
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, forType type: PKPushType) {
        NSLog("pushRegistry:didUpdatePushCredentials:forType:")
        
        if (type != .voIP) {
            return
        }

        guard let accessToken = fetchAccessToken() else {
            return
        }
        
        let deviceToken = (credentials.token as NSData).description

        TwilioVoice.register(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
            if (error != nil) {
                NSLog("An error occurred while registering: \(error?.localizedDescription)")
            }
            else {
                NSLog("Successfully registered for VoIP push notifications.")
            }
        }

        self.deviceTokenString = deviceToken
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenForType type: PKPushType) {
        NSLog("pushRegistry:didInvalidatePushTokenForType:")
        
        if (type != .voIP) {
            return
        }
        
        guard let deviceToken = deviceTokenString, let accessToken = fetchAccessToken() else {
            return
        }
        
        TwilioVoice.unregister(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
            if (error != nil) {
                NSLog("An error occurred while unregistering: \(error?.localizedDescription)")
            }
            else {
                NSLog("Successfully unregistered from VoIP push notifications.")
            }
        }
        
        self.deviceTokenString = nil
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, forType type: PKPushType) {
        NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:")

        if (type == PKPushType.voIP) {
            TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
        }
    }


    // MARK: TVONotificaitonDelegate
    func callInviteReceived(_ callInvite: TVOCallInvite) {
        if (callInvite.state == .pending) {
            handleCallInviteReceived(callInvite)
        } else if (callInvite.state == .canceled) {
            handleCallInviteCanceled(callInvite)
        }
    }
    
    func handleCallInviteReceived(_ callInvite: TVOCallInvite) {
        NSLog("callInviteReceived:")
        
        if (self.callInvite != nil && self.callInvite?.state == .pending) {
            NSLog("Already a pending incoming call invite.");
            NSLog("  >> Ignoring call from %@", callInvite.from);
            return;
        } else if (self.call != nil) {
            NSLog("Already an active call.");
            NSLog("  >> Ignoring call from %@", callInvite.from);
            return;
        }
        
        self.callInvite = callInvite

        reportIncomingCall(from: "Voice Bot", uuid: callInvite.uuid)
    }
    
    func handleCallInviteCanceled(_ callInvite: TVOCallInvite) {
        NSLog("callInviteCanceled:")
        
        performEndCallAction(uuid: callInvite.uuid)

        self.callInvite = nil
    }
    
    func notificationError(_ error: Error) {
        NSLog("notificationError: \(error.localizedDescription)")
    }
    
    
    // MARK: TVOCallDelegate
    func callDidConnect(_ call: TVOCall) {
        NSLog("callDidConnect:")
        
        self.call = call
        self.callKitCompletionCallback!(true)
        self.callKitCompletionCallback = nil
        
        self.placeCallButton.setTitle("Hang Up", for: .normal)
        
        toggleUIState(isEnabled: true)
        stopSpin()
        routeAudioToSpeaker()
    }
    
    func call(_ call: TVOCall, didFailToConnectWithError error: Error) {
        NSLog("Call failed to connect: \(error.localizedDescription)")
        
        if let completion = self.callKitCompletionCallback {
            completion(false)
        }
        
        /**
         * 1. performVoiceCall mutates call.uuid by setting it to a non-null value.
         * 2. performOutgoingVoiceCall produces a call with a valid UUID.
         */
        performEndCallAction(uuid: call.uuid)
        callDisconnected()
    }
    
    func call(_ call: TVOCall, didDisconnectWithError error: Error?) {
        if let error = error {
            NSLog("Call failed: \(error.localizedDescription)")
        } else {
            NSLog("Call disconnected")
        }
        
        /**
         * 1. performVoiceCall mutates call.uuid by setting it to a non-null value.
         * 2. performOutgoingVoiceCall produces a call with a valid UUID.
         */
        performEndCallAction(uuid: call.uuid)
        callDisconnected()
    }
    
    func callDisconnected() {
        self.call = nil
        self.callKitCompletionCallback = nil
        
        stopSpin()
        toggleUIState(isEnabled: true)
        self.placeCallButton.setTitle("Place Outgoing Call", for: .normal)
    }
    
    
    // MARK: AVAudioSession
    func routeAudioToSpeaker() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
        } catch {
            NSLog(error.localizedDescription)
        }
    }


    // MARK: Icon spinning
    func startSpin() {
        if (isSpinning != true) {
            isSpinning = true
            spin(options: UIViewAnimationOptions.curveEaseIn)
        }
    }
    
    func stopSpin() {
        isSpinning = false
    }
    
    func spin(options: UIViewAnimationOptions) {
        UIView.animate(withDuration: 0.5,
                       delay: 0.0,
                       options: options,
                       animations: { [weak iconView] in
            if let iconView = iconView {
                iconView.transform = iconView.transform.rotated(by: CGFloat(Double.pi/2))
            }
        }) { [weak self] (finished: Bool) in
            guard let strongSelf = self else {
                return
            }

            if (finished) {
                if (strongSelf.isSpinning) {
                    strongSelf.spin(options: UIViewAnimationOptions.curveLinear)
                } else if (options != UIViewAnimationOptions.curveEaseOut) {
                    strongSelf.spin(options: UIViewAnimationOptions.curveEaseOut)
                }
            }
        }
    }


    // MARK: CXProviderDelegate
    func providerDidReset(_ provider: CXProvider) {
        NSLog("providerDidReset:")
    }

    func providerDidBegin(_ provider: CXProvider) {
        NSLog("providerDidBegin")
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        NSLog("provider:didActivateAudioSession:")

        TwilioVoice.startAudio()
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        NSLog("provider:didDeactivateAudioSession:")
        
        TwilioVoice.stopAudio()
    }

    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        NSLog("provider:timedOutPerformingAction:")
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        NSLog("provider:performStartCallAction:")
        
        toggleUIState(isEnabled: false)
        startSpin()

        TwilioVoice.configureAudioSession()
        
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        
        self.performVoiceCall(uuid: action.callUUID, client: "") { (success) in
            if (success) {
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
                action.fulfill()
            } else {
                action.fail()
            }
        }
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        NSLog("provider:performAnswerCallAction:")

        // RCP: Workaround from https://forums.developer.apple.com/message/169511 suggests configuring audio in the
        //      completion block of the `reportNewIncomingCallWithUUID:update:completion:` method instead of in
        //      `provider:performAnswerCallAction:` per the WWDC examples.
        // TwilioVoice.configureAudioSession()
        
        self.performAnswerVoiceCall(uuid: action.callUUID) { (success) in
            if (success) {
                action.fulfill()
            } else {
                action.fail()
            }
        }
        
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        NSLog("provider:performEndCallAction:")

        if (self.callInvite != nil && self.callInvite?.state == .pending) {
            self.callInvite?.reject()
            self.callInvite = nil
        } else if (self.call != nil) {
            self.call?.disconnect()
        }

        action.fulfill()
    }

    // MARK: Call Kit Actions
    func performStartCallAction(uuid: UUID, handle: String) {
        let callHandle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: uuid, handle: callHandle)
        let transaction = CXTransaction(action: startCallAction)

        callKitCallController.request(transaction)  { error in
            if let error = error {
                NSLog("StartCallAction transaction request failed: \(error.localizedDescription)")
                return
            }

            NSLog("StartCallAction transaction request successful")

            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = callHandle
            callUpdate.supportsDTMF = true
            callUpdate.supportsHolding = false
            callUpdate.supportsGrouping = false
            callUpdate.supportsUngrouping = false
            callUpdate.hasVideo = false

            self.callKitProvider.reportCall(with: uuid, updated: callUpdate)
        }
    }

    func reportIncomingCall(from: String, uuid: UUID) {
        let callHandle = CXHandle(type: .generic, value: from)

        let callUpdate = CXCallUpdate()
        callUpdate.remoteHandle = callHandle
        callUpdate.supportsDTMF = true
        callUpdate.supportsHolding = false
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false

        callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            if let error = error {
                NSLog("Failed to report incoming call successfully: \(error.localizedDescription).")
                return
            }

            NSLog("Incoming call successfully reported.")

            // RCP: Workaround per https://forums.developer.apple.com/message/169511
            TwilioVoice.configureAudioSession()
        }
    }

    func performEndCallAction(uuid: UUID) {

        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)

        callKitCallController.request(transaction) { error in
            if let error = error {
                NSLog("EndCallAction transaction request failed: \(error.localizedDescription).")
                return
            }

            NSLog("EndCallAction transaction request successful")
        }
    }
    
    func performVoiceCall(uuid: UUID, client: String?, completionHandler: @escaping (Bool) -> Swift.Void) {
        guard let accessToken = fetchAccessToken() else {
            completionHandler(false)
            return
        }
        
        call = TwilioVoice.call(accessToken, params: [:], uuid:uuid, delegate: self)
        self.callKitCompletionCallback = completionHandler
    }
    
    func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Swift.Void) {
        call = self.callInvite?.accept(with: self)
        self.callInvite = nil
        self.callKitCompletionCallback = completionHandler
    }
}
