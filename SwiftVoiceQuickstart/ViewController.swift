//
//  ViewController.swift
//  Twilio Voice Quickstart - Swift
//
//  Copyright © 2016-2018 Twilio, Inc. All rights reserved.
//

import AVFoundation
import PushKit
import TwilioVoice
import UIKit
import UserNotifications

let baseURLString = <#URL TO YOUR ACCESS TOKEN SERVER#>
// If your token server is written in PHP, accessTokenEndpoint needs .php extension at the end. For example : /accessToken.php
let accessTokenEndpoint = "/accessToken"
let identity = "alice"
let twimlParamTo = "to"

class ViewController: UIViewController, PKPushRegistryDelegate, TVONotificationDelegate, TVOCallDelegate, AVAudioPlayerDelegate, UITextFieldDelegate {

    @IBOutlet weak var placeCallButton: UIButton!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var outgoingValue: UITextField!
    @IBOutlet weak var callControlView: UIView!
    @IBOutlet weak var muteSwitch: UISwitch!
    @IBOutlet weak var speakerSwitch: UISwitch!
    
    var deviceTokenString:String?

    var voipRegistry:PKPushRegistry
    var incomingPushCompletionCallback: (()->Swift.Void?)? = nil

    var isSpinning: Bool
    var incomingAlertController: UIAlertController?

    var callInvite:TVOCallInvite?
    var call:TVOCall?
    
    var ringtonePlayer:AVAudioPlayer?
    var ringtonePlaybackCallback: (() -> ())?

    required init?(coder aDecoder: NSCoder) {
        isSpinning = false
        voipRegistry = PKPushRegistry.init(queue: DispatchQueue.main)

        super.init(coder: aDecoder)

        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = Set([PKPushType.voIP])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        toggleUIState(isEnabled: true, showCallControl: false)
        outgoingValue.delegate = self
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
        if (self.call != nil) {
            self.call?.disconnect()
            self.toggleUIState(isEnabled: false, showCallControl: false)
        } else {
            playOutgoingRingtone(completion: { [weak self] in
                if let strongSelf = self {
                    strongSelf.makeCall(strongSelf.outgoingValue.text!)
                }
            })
            
            self.toggleUIState(isEnabled: false, showCallControl: false)
            self.startSpin()
        }
    }
    
    func makeCall(_ to: String) {
        guard let accessToken = fetchAccessToken() else {
            return
        }
        
        let connectOptions: TVOConnectOptions = TVOConnectOptions(accessToken: accessToken) { (builder) in
            builder.params = [twimlParamTo : to]
        }
        
        self.checkRecordPermission { (permissionGranted) in
            if (!permissionGranted) {
                let alertController: UIAlertController = UIAlertController(title: "Voice Quick Start",
                                                                           message: "Microphone permission not granted",
                                                                           preferredStyle: .alert)
                
                let continueWithMic: UIAlertAction = UIAlertAction(title: "Continue without microphone",
                                                                   style: .default,
                                                                   handler: { (action) in
                    self.call = TwilioVoice.connect(with: connectOptions, delegate: self)
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
                self.call = TwilioVoice.connect(with: connectOptions, delegate: self)
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
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        NSLog("pushRegistry:didUpdatePushCredentials:forType:");
        
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
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
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
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:")

        if (type == PKPushType.voIP) {
            TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
        }
    }
    
    /**
     * This delegate method is available in iOS 11 and above. Call the completion handler once the
     * notification payload is passed to the `TwilioVoice.handleNotification()` method.
     */
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        NSLog("pushRegistry:didReceiveIncomingPushWithPayload:forType:completion:")
        // Save for later when the notification is properly handled.
        self.incomingPushCompletionCallback = completion
        
        if (type == PKPushType.voIP) {
            TwilioVoice.handleNotification(payload.dictionaryPayload, delegate: self)
        }
    }
    
    func incomingPushHandled() {
        if let completion = self.incomingPushCompletionCallback {
            completion()
            self.incomingPushCompletionCallback = nil
        }
    }

    // MARK: TVONotificaitonDelegate
    func callInviteReceived(_ callInvite: TVOCallInvite) {
        NSLog("callInviteReceived:")
        
        if (self.callInvite != nil) {
            NSLog("A CallInvite is already in progress. Ignoring the incoming CallInvite from \(callInvite.from)")
            self.incomingPushHandled()
            return
        } else if (self.call != nil && self.call?.state == .connected) {
            NSLog("Already an active call. Ignoring incoming CallInvite from \(callInvite.from)");
            self.incomingPushHandled()
            return;
        }
        
        self.callInvite = callInvite;
        
        let from = callInvite.from
        let alertMessage = "From: \(from)"
        
        playIncomingRingtone()
        
        let incomingAlertController = UIAlertController(title: "Incoming",
                                                        message: alertMessage,
                                                        preferredStyle: .alert)

        let rejectAction = UIAlertAction(title: "Reject", style: .default) { [weak self] (action) in
            if let strongSelf = self {
                strongSelf.stopIncomingRingtone()
                callInvite.reject()
                strongSelf.callInvite = nil
                
                strongSelf.incomingAlertController = nil
                strongSelf.toggleUIState(isEnabled: true, showCallControl: false)
            }
        }
        incomingAlertController.addAction(rejectAction)
        
        let ignoreAction = UIAlertAction(title: "Ignore", style: .default) { [weak self] (action) in
            if let strongSelf = self {
                /* To ignore the CallInvite, you don't have to do anything but just literally ignore it */
                
                strongSelf.callInvite = nil
                strongSelf.stopIncomingRingtone()
                strongSelf.incomingAlertController = nil
                strongSelf.toggleUIState(isEnabled: true, showCallControl: false)
            }
        }
        incomingAlertController.addAction(ignoreAction)
        
        let acceptAction = UIAlertAction(title: "Accept", style: .default) { [weak self] (action) in
            if let strongSelf = self {
                strongSelf.stopIncomingRingtone()
                let acceptOptions: TVOAcceptOptions = TVOAcceptOptions(callInvite: callInvite) { (builder) in
                    builder.uuid = strongSelf.callInvite?.uuid
                }
                strongSelf.call = callInvite.accept(with: acceptOptions, delegate: strongSelf)
                strongSelf.callInvite = nil
                
                strongSelf.incomingAlertController = nil
                strongSelf.startSpin()
            }
        }
        incomingAlertController.addAction(acceptAction)
        
        toggleUIState(isEnabled: false, showCallControl: false)
        present(incomingAlertController, animated: true, completion: nil)
        self.incomingAlertController = incomingAlertController

        // If the application is not in the foreground, post a local notification
        if (UIApplication.shared.applicationState != UIApplicationState.active) {
            let content = UNMutableNotificationContent()
            content.title = "Incoming Call"
            content.body = "Call Invite from \(callInvite.from)"
            content.sound = UNNotificationSound.default()
            
            let request = UNNotificationRequest(identifier: "VoiceLocaNotification",
                                                content: content, trigger: nil)
            
            let center = UNUserNotificationCenter.current()
            center.add(request) { (error) in
                if (error != nil) {
                    print("Failed to add notification reqeust: \(error!.localizedDescription)")
                }
            }
        }
        
        self.incomingPushHandled()
    }
    
    func cancelledCallInviteReceived(_ cancelledCallInvite: TVOCancelledCallInvite) {
        NSLog("cancelledCallInviteCanceled:")
        
        if (self.callInvite == nil ||
            self.callInvite!.callSid != cancelledCallInvite.callSid) {
            NSLog("No matching pending CallInvite. Ignoring the Cancelled CallInvite")
            return
        }
        
        self.stopIncomingRingtone()
        playDisconnectSound()
        
        if (incomingAlertController != nil) {
            dismiss(animated: true) { [weak self] in
                if let strongSelf = self {
                    strongSelf.incomingAlertController = nil
                    strongSelf.toggleUIState(isEnabled: true, showCallControl: false)
                }
            }
        }
        
        self.callInvite = nil
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        self.incomingPushHandled()
    }

    // MARK: TVOCallDelegate
    func callDidConnect(_ call: TVOCall) {
        NSLog("callDidConnect:")
        
        self.call = call
        
        self.placeCallButton.setTitle("Hang Up", for: .normal)
        
        toggleUIState(isEnabled: true, showCallControl: true)
        stopSpin()
        toggleAudioRoute(toSpeaker: true)
    }
    
    func call(_ call: TVOCall, didFailToConnectWithError error: Error) {
        NSLog("Call failed to connect: \(error.localizedDescription)")
        
        callDisconnected()
    }
    
    func call(_ call: TVOCall, didDisconnectWithError error: Error?) {
        if let error = error {
            NSLog("Call failed: \(error.localizedDescription)")
        } else {
            NSLog("Call disconnected")
        }
        
        callDisconnected()
    }
    
    func callDisconnected() {
        self.call = nil
        
        playDisconnectSound()
        toggleUIState(isEnabled: true, showCallControl: false)
        stopSpin()
        self.placeCallButton.setTitle("Call", for: .normal)
    }
    
    
    // MARK: AVAudioSession
    func toggleAudioRoute(toSpeaker: Bool) {
        // The mode set by the Voice SDK is "VoiceChat" so the default audio route is the built-in receiver. Use port override to switch the route.
        let audioDevice: TVODefaultAudioDevice = TwilioVoice.audioDevice as! TVODefaultAudioDevice
        audioDevice.block = {
            kTVODefaultAVAudioSessionConfigurationBlock()
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
    
    
    // MARK: Ringtone player & AVAudioPlayerDelegate
    func playOutgoingRingtone(completion: @escaping () -> ()) {
        self.ringtonePlaybackCallback = completion
        
        let ringtonePath = URL(fileURLWithPath: Bundle.main.path(forResource: "outgoing", ofType: "wav")!)
        do {
            self.ringtonePlayer = try AVAudioPlayer(contentsOf: ringtonePath)
            self.ringtonePlayer?.delegate = self
            
            playRingtone()
        } catch {
            NSLog("Failed to initialize audio player")
            self.ringtonePlaybackCallback?()
        }
    }
    
    func playIncomingRingtone() {
        let ringtonePath = URL(fileURLWithPath: Bundle.main.path(forResource: "incoming", ofType: "wav")!)
        do {
            self.ringtonePlayer = try AVAudioPlayer(contentsOf: ringtonePath)
            self.ringtonePlayer?.delegate = self
            self.ringtonePlayer?.numberOfLoops = -1
            
            playRingtone()
        } catch {
            NSLog("Failed to initialize audio player")
        }
    }
    
    func stopIncomingRingtone() {
        if (self.ringtonePlayer?.isPlaying == false) {
            return
        }
        
        self.ringtonePlayer?.stop()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
        } catch {
            NSLog(error.localizedDescription)
        }
    }
    
    func playDisconnectSound() {
        let ringtonePath = URL(fileURLWithPath: Bundle.main.path(forResource: "disconnect", ofType: "wav")!)
        do {
            self.ringtonePlayer = try AVAudioPlayer(contentsOf: ringtonePath)
            self.ringtonePlayer?.delegate = self
            self.ringtonePlaybackCallback = nil
            
            playRingtone()
        } catch {
            NSLog("Failed to initialize audio player")
        }
    }
    
    func playRingtone() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            NSLog(error.localizedDescription)
        }
        
        self.ringtonePlayer?.volume = 1.0
        self.ringtonePlayer?.play()
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if (self.ringtonePlaybackCallback != nil) {
            DispatchQueue.main.async {
                self.ringtonePlaybackCallback!()
            }
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord)
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
}

