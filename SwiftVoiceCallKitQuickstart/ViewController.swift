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
// If your token server is written in PHP, accessTokenEndpoint needs .php extension at the end. For example : /accessToken.php
let accessTokenEndpoint = "/accessToken"
let identity = "alice"
let twimlParamTo = "to"

class ViewController: UIViewController, PKPushRegistryDelegate, TVONotificationDelegate, TVOCallDelegate, CXProviderDelegate, UITextFieldDelegate {

    @IBOutlet weak var placeCallButton: UIButton!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var outgoingValue: UITextField!
    @IBOutlet weak var callControlView: UIView!
    @IBOutlet weak var muteSwitch: UISwitch!
    @IBOutlet weak var speakerSwitch: UISwitch!
    
    var deviceTokenString: String?

    var voipRegistry: PKPushRegistry

    var isSpinning: Bool
    var incomingAlertController: UIAlertController?

    var callInvite: TVOCallInvite?
    var call: TVOCall?
    var callKitCompletionCallback: ((Bool)->Swift.Void?)? = nil
    var audioDevice: TVODefaultAudioDevice = TVODefaultAudioDevice()

    let callKitProvider: CXProvider
    let callKitCallController: CXCallController
    var userInitiatedDisconnect: Bool = false

    required init?(coder aDecoder: NSCoder) {
        isSpinning = false
        voipRegistry = PKPushRegistry.init(queue: DispatchQueue.main)

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

        toggleUIState(isEnabled: true, showCallControl: false)
        outgoingValue.delegate = self
        
        /*
         * The important thing to remember when providing a TVOAudioDevice is that the device must be set
         * before performing any other actions with the SDK (such as connecting a Call, or accepting an incoming Call).
         * In this case we've already initialized our own `TVODefaultAudioDevice` instance which we will now set.
         */
        TwilioVoice.audioDevice = audioDevice
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    func fetchAccessToken() -> String? {
        let endpointWithIdentity = String(format: "%@?identity=%@", accessTokenEndpoint, identity)
        guard let accessTokenURL = URL(string: baseURLString + endpointWithIdentity) else {
            return nil
        }
        
        return try? String.init(contentsOf: accessTokenURL, encoding: .utf8)
    }

    func toggleUIState(isEnabled: Bool, showCallControl: Bool) {
        placeCallButton.isEnabled = isEnabled
        if (showCallControl) {
            callControlView.isHidden = false
            muteSwitch.isOn = false
            speakerSwitch.isOn = true
        } else {
            callControlView.isHidden = true
        }
    }

    @IBAction func placeCall(_ sender: UIButton) {
        if (self.call != nil && self.call?.state == .connected) {
            self.userInitiatedDisconnect = true
            performEndCallAction(uuid: self.call!.uuid)
            self.toggleUIState(isEnabled: false, showCallControl: false)
        } else {
            let uuid = UUID()
            let handle = "Voice Bot"
            
            self.checkRecordPermission { (permissionGranted) in
                if (!permissionGranted) {
                    let alertController: UIAlertController = UIAlertController(title: "Voice Quick Start",
                                                                               message: "Microphone permission not granted",
                                                                               preferredStyle: .alert)
                    
                    let continueWithMic: UIAlertAction = UIAlertAction(title: "Continue without microphone",
                                                                       style: .default,
                                                                       handler: { (action) in
                        self.performStartCallAction(uuid: uuid, handle: handle)
                    })
                    alertController.addAction(continueWithMic)
                    
                    let goToSettings: UIAlertAction = UIAlertAction(title: "Settings",
                                                                    style: .default,
                                                                    handler: { (action) in
                        UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!,
                                                  options: [UIApplicationOpenURLOptionUniversalLinksOnly: false],
                                                  completionHandler: nil)
                    })
                    alertController.addAction(goToSettings)
                    
                    let cancel: UIAlertAction = UIAlertAction(title: "Cancel",
                                                              style: .cancel,
                                                              handler: { (action) in
                        self.toggleUIState(isEnabled: true, showCallControl: false)
                        self.stopSpin()
                    })
                    alertController.addAction(cancel)
                    
                    self.present(alertController, animated: true, completion: nil)
                } else {
                    self.performStartCallAction(uuid: uuid, handle: handle)
                }
            }
        }
    }
    
    func checkRecordPermission(completion: @escaping (_ permissionGranted: Bool) -> Void) {
        let permissionStatus: AVAudioSessionRecordPermission = AVAudioSession.sharedInstance().recordPermission()
        
        switch permissionStatus {
        case AVAudioSessionRecordPermission.granted:
            // Record permission already granted.
            completion(true)
            break
        case AVAudioSessionRecordPermission.denied:
            // Record permission denied.
            completion(false)
            break
        case AVAudioSessionRecordPermission.undetermined:
            // Requesting record permission.
            // Optional: pop up app dialog to let the users know if they want to request.
            AVAudioSession.sharedInstance().requestRecordPermission({ (granted) in
                completion(granted)
            })
            break
        default:
            completion(false)
            break
        }
    }
    
    @IBAction func muteSwitchToggled(_ sender: UISwitch) {
        if let call = call {
            call.isMuted = sender.isOn
        } else {
            NSLog("No active call to be muted")
        }
    }
    
    @IBAction func speakerSwitchToggled(_ sender: UISwitch) {
        toggleAudioRoute(toSpeaker: sender.isOn)
    }
    
    // MARK: UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        outgoingValue.resignFirstResponder()
        return true
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
            if let error = error {
                NSLog("An error occurred while registering: \(error.localizedDescription)")
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
            if let error = error {
                NSLog("An error occurred while unregistering: \(error.localizedDescription)")
            }
            else {
                NSLog("Successfully unregistered from VoIP push notifications.")
            }
        }
        
        self.deviceTokenString = nil
    }

    /**
     * Try using the `pushRegistry:didReceiveIncomingPushWithPayload:forType:withCompletionHandler:` method if
     * your application is targeting iOS 11. According to the docs, this delegate method is deprecated by Apple.
     */
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, forType type: PKPushType) {
        NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:")

        if (type == PKPushType.voIP) {
            TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
        }
    }

    /**
     * This delegate method is available on iOS 11 and above. Call the completion handler once the
     * notification payload is passed to the `TwilioVoice.handleNotification()` method.
     */
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:completion:")
        
        if (type == PKPushType.voIP) {
            TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
        }
        
        DispatchQueue.main.async {
            completion()
        }
    }

    // MARK: TVONotificaitonDelegate
    func callInviteReceived(_ callInvite: TVOCallInvite) {
        NSLog("callInviteReceived:")
        
        if (self.callInvite != nil) {
            NSLog("A CallInvite is already in progress. Ignoring the incoming CallInvite from \(callInvite.from)")
            return;
        } else if (self.call != nil) {
            NSLog("Already an active call.");
            NSLog("  >> Ignoring call from %@", callInvite.from);
            return;
        }
        
        self.callInvite = callInvite

        reportIncomingCall(from: "Voice Bot", uuid: callInvite.uuid)
    }
    
    func cancelledCallInviteReceived(_ cancelledCallInvite: TVOCancelledCallInvite) {
        NSLog("cancelledCallInviteCanceled:")
        
        if (self.callInvite == nil ||
            self.callInvite!.callSid != cancelledCallInvite.callSid) {
            NSLog("No matching pending CallInvite. Ignoring the Cancelled CallInvite")
            return
        }
        
        performEndCallAction(uuid: self.callInvite!.uuid)

        self.callInvite = nil
    }

    // MARK: TVOCallDelegate
    func callDidConnect(_ call: TVOCall) {
        NSLog("callDidConnect:")
        
        self.call = call
        self.callKitCompletionCallback!(true)
        self.callKitCompletionCallback = nil
        
        self.placeCallButton.setTitle("Hang Up", for: .normal)
        
        toggleUIState(isEnabled: true, showCallControl: true)
        stopSpin()
        toggleAudioRoute(toSpeaker: true)
    }
    
    func call(_ call: TVOCall, didFailToConnectWithError error: Error) {
        NSLog("Call failed to connect: \(error.localizedDescription)")
        
        if let completion = self.callKitCompletionCallback {
            completion(false)
        }

        performEndCallAction(uuid: call.uuid)
        callDisconnected()
    }
    
    func call(_ call: TVOCall, didDisconnectWithError error: Error?) {
        if let error = error {
            NSLog("Call failed: \(error.localizedDescription)")
        } else {
            NSLog("Call disconnected")
        }
        
        if !self.userInitiatedDisconnect {
            var reason = CXCallEndedReason.remoteEnded
            
            if error != nil {
                reason = .failed
            }
            
            self.callKitProvider.reportCall(with: call.uuid, endedAt: Date(), reason: reason)
        }

        callDisconnected()
    }
    
    func callDisconnected() {
        self.call = nil
        self.callKitCompletionCallback = nil
        self.userInitiatedDisconnect = false
        
        stopSpin()
        toggleUIState(isEnabled: true, showCallControl: false)
        self.placeCallButton.setTitle("Call", for: .normal)
    }
    
    
    // MARK: AVAudioSession
    func toggleAudioRoute(toSpeaker: Bool) {
        // The mode set by the Voice SDK is "VoiceChat" so the default audio route is the built-in receiver. Use port override to switch the route.
        audioDevice.block = {
            kDefaultAVAudioSessionConfigurationBlock()
            do {
                if (toSpeaker) {
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
        audioDevice.isEnabled = true
    }

    func providerDidBegin(_ provider: CXProvider) {
        NSLog("providerDidBegin")
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        NSLog("provider:didActivateAudioSession:")
        audioDevice.isEnabled = true
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        NSLog("provider:didDeactivateAudioSession:")
    }

    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        NSLog("provider:timedOutPerformingAction:")
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        NSLog("provider:performStartCallAction:")
        
        toggleUIState(isEnabled: false, showCallControl: false)
        startSpin()

        audioDevice.isEnabled = false
        audioDevice.block();
        
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

        assert(action.callUUID == self.callInvite?.uuid)
        
        audioDevice.isEnabled = false
        audioDevice.block();
        
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

        if (self.callInvite != nil) {
            self.callInvite!.reject()
            self.callInvite = nil
        } else if (self.call != nil) {
            self.call?.disconnect()
        }

        audioDevice.isEnabled = true
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        NSLog("provider:performSetHeldAction:")
        if (self.call?.state == .connected) {
            self.call?.isOnHold = action.isOnHold
            action.fulfill()
        } else {
            action.fail()
        }
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
            callUpdate.supportsHolding = true
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
        callUpdate.supportsHolding = true
        callUpdate.supportsGrouping = false
        callUpdate.supportsUngrouping = false
        callUpdate.hasVideo = false

        callKitProvider.reportNewIncomingCall(with: uuid, update: callUpdate) { error in
            if let error = error {
                NSLog("Failed to report incoming call successfully: \(error.localizedDescription).")
                return
            }

            NSLog("Incoming call successfully reported.")
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
        
        let connectOptions: TVOConnectOptions = TVOConnectOptions(accessToken: accessToken) { (builder) in
            builder.params = [twimlParamTo : self.outgoingValue.text!]
            builder.uuid = uuid
        }
        call = TwilioVoice.connect(with: connectOptions, delegate: self)
        self.callKitCompletionCallback = completionHandler
    }
    
    func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Swift.Void) {
        let acceptOptions: TVOAcceptOptions = TVOAcceptOptions(callInvite: self.callInvite!) { (builder) in
            builder.uuid = self.callInvite?.uuid
        }
        call = self.callInvite?.accept(with: acceptOptions, delegate: self)
        self.callInvite = nil
        self.callKitCompletionCallback = completionHandler
    }
}
