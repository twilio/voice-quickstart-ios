//
//  ViewController.swift
//  Twilio Voice Quickstart - Swift
//
//  Copyright © 2016 Twilio, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import PushKit
import TwilioVoiceClient

let baseURLString = <#URL TO YOUR ACCESS TOKEN SERVER#>
let accessTokenEndpoint = "/accessToken"

class ViewController: UIViewController, PKPushRegistryDelegate, TVONotificationDelegate, TVOIncomingCallDelegate, TVOOutgoingCallDelegate, AVAudioPlayerDelegate {

    @IBOutlet weak var placeCallButton: UIButton!
    @IBOutlet weak var iconView: UIImageView!

    var deviceTokenString:String?

    var voipRegistry:PKPushRegistry

    var isSpinning: Bool
    var incomingAlertController: UIAlertController?

    var incomingCall:TVOIncomingCall?
    var outgoingCall:TVOOutgoingCall?
    
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
        guard let accessToken = fetchAccessToken() else {
            return
        }
        
        playOutgoingRingtone(completion: { [weak self] in
            if let strongSelf = self {
                strongSelf.outgoingCall = VoiceClient.sharedInstance().call(accessToken, params: [:], delegate: strongSelf)
                
                if (strongSelf.outgoingCall == nil) {
                    NSLog("Failed to start outgoing call")
                    return
                } else {
                    strongSelf.toggleUIState(isEnabled: false)
                    strongSelf.startSpin()
                }
            }
        })
    }


    // MARK: PKPushRegistryDelegate
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, forType type: PKPushType) {
        NSLog("pushRegistry:didUpdatePushCredentials:forType:");
        
        if (type != .voIP) {
            return
        }

        guard let accessToken = fetchAccessToken() else {
            return
        }
        
        let deviceToken = (credentials.token as NSData).description

        VoiceClient.sharedInstance().register(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
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
        
        VoiceClient.sharedInstance().unregister(withAccessToken: accessToken, deviceToken: deviceToken) { (error) in
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
            VoiceClient.sharedInstance().handleNotification(payload.dictionaryPayload, delegate: self)
        }
    }


    // MARK: TVONotificaitonDelegate
    func incomingCallReceived(_ incomingCall: TVOIncomingCall) {
        NSLog("incomingCallReceived:")
        
        if (self.incomingCall != nil || self.outgoingCall != nil) {
            NSLog("Already an active call. Ignoring incoming call from \(incomingCall.from)");
            return;
        }
        
        self.incomingCall = incomingCall;
        self.incomingCall?.delegate = self;

        
        let from = incomingCall.from
        let alertMessage = "From: \(from)"
        
        playIncomingRingtone()
        
        let incomingAlertController = UIAlertController(title: "Incoming",
                                                        message: alertMessage,
                                                        preferredStyle: .alert)

        let rejectAction = UIAlertAction(title: "Reject", style: .default) { [weak self] (action) in
            if let strongSelf = self {
                strongSelf.stopIncomingRingtone(completion: {_ in
                    incomingCall.reject()
                })
                strongSelf.incomingAlertController = nil
                strongSelf.toggleUIState(isEnabled: true)
            }
        }
        incomingAlertController.addAction(rejectAction)
        
        let ignoreAction = UIAlertAction(title: "Ignore", style: .default) { [weak self] (action) in
            if let strongSelf = self {
                strongSelf.stopIncomingRingtone(completion: nil)
                incomingCall.ignore()
                strongSelf.incomingAlertController = nil
                strongSelf.toggleUIState(isEnabled: true)
            }
        }
        incomingAlertController.addAction(ignoreAction)
        
        let acceptAction = UIAlertAction(title: "Accept", style: .default) { [weak self] (action) in
            if let strongSelf = self {
                strongSelf.stopIncomingRingtone(completion: {_ in
                    incomingCall.accept(with: strongSelf)
                })

                strongSelf.incomingAlertController = nil
                strongSelf.startSpin()
            }
        }
        incomingAlertController.addAction(acceptAction)
        
        toggleUIState(isEnabled: false)
        present(incomingAlertController, animated: true, completion: nil)
        self.incomingAlertController = incomingAlertController

        // If the application is not in the foreground, post a local notification
        if (UIApplication.shared.applicationState != UIApplicationState.active) {
            let notification = UILocalNotification()
            notification.alertBody = "Incoming Call From \(from)"
            
            UIApplication.shared.presentLocalNotificationNow(notification)
        }
    }
    
    func incomingCallCancelled(_ incomingCall: TVOIncomingCall?) {
        NSLog("incomingCallCancelled:")
        
        if (incomingCall?.callSid != self.incomingCall?.callSid) {
            NSLog("Incoming (but not current) call from \(incomingCall?.from) cancelled. Just ignore it.");
            return;
        }
        
        self.stopIncomingRingtone(completion: nil)
        playDisconnectSound()
        
        if (incomingAlertController != nil) {
            dismiss(animated: true) { [weak self] in
                if let strongSelf = self {
                    strongSelf.incomingAlertController = nil
                    strongSelf.toggleUIState(isEnabled: true)
                }
            }
        }
        
        self.incomingCall = nil
        
        UIApplication.shared.cancelAllLocalNotifications()
    }
    
    func notificationError(_ error: Error) {
        NSLog("notificationError: \(error.localizedDescription)")
    }
    
    
    // MARK: TVOIncomingCallDelegate
    func incomingCallDidConnect(_ incomingCall: TVOIncomingCall) {
        NSLog("incomingCallDidConnect:")
        
        self.incomingCall = incomingCall
        toggleUIState(isEnabled: false)
        stopSpin()
        routeAudioToSpeaker()
    }
    
    func incomingCallDidDisconnect(_ incomingCall: TVOIncomingCall) {
        NSLog("incomingCallDidDisconnect:")
        
        playDisconnectSound()
        
        self.incomingCall = nil
        toggleUIState(isEnabled: true)
    }
    
    func incomingCall(_ incomingCall: TVOIncomingCall, didFailWithError error: Error) {
        NSLog("incomingCall:didFailWithError: \(error.localizedDescription)");
        
        self.incomingCall = nil
        toggleUIState(isEnabled: true)
        stopSpin()
    }
    
    
    // MARK: TVOOutgoingCallDelegate
    func outgoingCallDidConnect(_ outgoingCall: TVOOutgoingCall) {
        NSLog("outgoingCallDidConnect:")
        
        self.outgoingCall = outgoingCall
        
        toggleUIState(isEnabled: false)
        stopSpin()
        routeAudioToSpeaker()
    }
    
    func outgoingCallDidDisconnect(_ outgoingCall: TVOOutgoingCall) {
        NSLog("outgoingCallDidDisconnect:")
        
        playDisconnectSound()
        
        self.outgoingCall = nil
        toggleUIState(isEnabled: true)
    }
    
    func outgoingCall(_ outgoingCall: TVOOutgoingCall, didFailWithError error: Error) {
        NSLog("outgoingCall:didFailWithError: \(error.localizedDescription)");
        
        self.outgoingCall = nil
        toggleUIState(isEnabled: true)
        stopSpin()
    }
    
    
    // MARK: AVAudioSession
    func routeAudioToSpeaker() {
        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        } catch {
            NSLog(error.localizedDescription)
        }
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
    
    func stopIncomingRingtone(completion: ((Void?) -> Void)?) {
        self.ringtonePlaybackCallback = completion
        if (self.ringtonePlayer?.isPlaying == false) {
            self.ringtonePlaybackCallback?()
            return
        }
        
        self.ringtonePlayer?.delegate = self
        self.ringtonePlayer?.numberOfLoops = 1
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
        
        self.routeAudioToSpeaker()
        
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
                iconView.transform = iconView.transform.rotated(by: CGFloat(M_PI/2))
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

