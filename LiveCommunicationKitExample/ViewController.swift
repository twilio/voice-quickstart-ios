//
//  ViewController.swift
//  Twilio Voice Quickstart - LiveCommunicationKit
//
//  Copyright © Twilio, Inc. All rights reserved.
//

import UIKit
import AVFoundation
import PushKit
import LiveCommunicationKit
import TwilioVoice

let accessToken = "PASTE_YOUR_ACCESS_TOKEN_HERE"
let twimlParamTo = "to"

let kRegistrationTTLInDays = 365

let kCachedDeviceToken = "CachedDeviceToken"
let kCachedBindingDate = "CachedBindingDate"

@available(iOS 17.4, *)
class ViewController: UIViewController {

    @IBOutlet weak var qualityWarningsToaster: UILabel!
    @IBOutlet weak var placeCallButton: UIButton!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var outgoingValue: UITextField!
    @IBOutlet weak var callControlView: UIView!
    @IBOutlet weak var muteSwitch: UISwitch!
    @IBOutlet weak var speakerSwitch: UISwitch!

    var incomingPushCompletionCallback: (() -> Void)?

    var isSpinning: Bool
    var incomingAlertController: UIAlertController?

    var conversationCompletionCallback: ((Bool) -> Void)? = nil
    var audioDevice = DefaultAudioDevice()
    var activeCallInvites: [String: CallInvite]! = [:]
    var activeCalls: [String: Call]! = [:]

    // activeCall represents the last connected call
    var activeCall: Call? = nil

    /*
     * The ConversationManager replaces CXProvider + CXCallController. A single ConversationManager
     * handles both the system UI for outgoing/incoming conversations and the request side
     * (manager.perform([action]) replaces callController.request(transaction)).
     */
    var conversationManager: ConversationManager!
    var userInitiatedDisconnect: Bool = false

    /*
     Custom ringback will be played when this flag is enabled.
     When [answerOnBridge](https://www.twilio.com/docs/voice/twiml/dial#answeronbridge) is enabled in
     the <Dial> TwiML verb, the caller will not hear the ringback while the call is ringing and awaiting
     to be accepted on the callee's side. Configure this flag based on the TwiML application.
    */
    var playCustomRingback = false
    var ringtonePlayer: AVAudioPlayer? = nil

    required init?(coder aDecoder: NSCoder) {
        isSpinning = false

        super.init(coder: aDecoder)
    }

    deinit {
        // Mirrors CXProvider.invalidate() — release the manager when the view controller is torn down.
        conversationManager?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        toggleUIState(isEnabled: true, showCallControl: false)
        outgoingValue.delegate = self

        let configuration = ConversationManager.Configuration(
            ringtoneName: nil,
            iconTemplateImageData: nil,
            maximumConversationGroups: 2,
            maximumConversationsPerConversationGroup: 1,
            includesConversationInRecents: true,
            supportsVideo: false,
            supportedHandleTypes: [.generic]
        )
        conversationManager = ConversationManager(configuration: configuration)
        conversationManager.delegate = self

        /*
         * The important thing to remember when providing a TVOAudioDevice is that the device must be set
         * before performing any other actions with the SDK (such as connecting a Call, or accepting an incoming Call).
         */
        TwilioVoiceSDK.audioDevice = audioDevice

        /* Example usage of Default logger to print app logs */
        let defaultLogger = TwilioVoiceSDK.logger
        if let params = LogParameters.init(module: TwilioVoiceSDK.LogModule.platform,
                                           logLevel: TwilioVoiceSDK.LogLevel.debug,
                                           message: "The default logger is used for app logs") {
            defaultLogger.log(params: params)
        }
    }

    func toggleUIState(isEnabled: Bool, showCallControl: Bool) {
        placeCallButton.isEnabled = isEnabled

        if showCallControl {
            callControlView.isHidden = false
            muteSwitch.isOn = getActiveCall()?.isMuted ?? false
            for output in AVAudioSession.sharedInstance().currentRoute.outputs {
                speakerSwitch.isOn = output.portType == AVAudioSession.Port.builtInSpeaker
            }
        } else {
            callControlView.isHidden = true
        }
    }

    func showMicrophoneAccessRequest(_ uuid: UUID, _ handle: String) {
        let alertController = UIAlertController(title: "Voice Quick Start",
                                                message: "Microphone permission not granted",
                                                preferredStyle: .alert)

        let continueWithoutMic = UIAlertAction(title: "Continue without microphone", style: .default) { [weak self] _ in
            self?.performStartConversationAction(uuid: uuid, handle: handle)
        }

        let goToSettings = UIAlertAction(title: "Settings", style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                      options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: false],
                                      completionHandler: nil)
        }

        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.toggleUIState(isEnabled: true, showCallControl: false)
            self?.stopSpin()
        }

        [continueWithoutMic, goToSettings, cancel].forEach { alertController.addAction($0) }

        present(alertController, animated: true, completion: nil)
    }

    func getActiveCall() -> Call? {
        if let activeCall = activeCall {
            return activeCall
        } else if activeCalls.count == 1 {
            // This is a scenario when the only remaining call is still on hold after the previous call has ended
            return activeCalls.first?.value
        } else {
            return nil
        }
    }

    @IBAction func mainButtonPressed(_ sender: Any) {
        if !activeCalls.isEmpty {
            guard let activeCall = getActiveCall() else { return }
            userInitiatedDisconnect = true
            performEndConversationAction(uuid: activeCall.uuid!)
            return
        }

        checkRecordPermission { [weak self] permissionGranted in
            let uuid = UUID()
            let handle = "Voice Bot"

            guard !permissionGranted else {
                self?.performStartConversationAction(uuid: uuid, handle: handle)
                return
            }
            DispatchQueue.main.async {
                self?.showMicrophoneAccessRequest(uuid, handle)
            }
        }
    }

    func checkRecordPermission(completion: @escaping (_ permissionGranted: Bool) -> Void) {
        let permissionStatus = AVAudioSession.sharedInstance().recordPermission

        switch permissionStatus {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in completion(granted) }
        default:
            completion(false)
        }
    }

    @IBAction func muteSwitchToggled(_ sender: UISwitch) {
        guard let activeCall = getActiveCall(), let uuid = activeCall.uuid else { return }

        // Route the mute through ConversationManager so the system UI stays in sync.
        let action = MuteConversationAction(conversationUUID: uuid, isMuted: sender.isOn)
        Task {
            do { try await conversationManager.perform([action]) }
            catch { NSLog("MuteConversationAction failed: \(error.localizedDescription)") }
        }
    }

    @IBAction func speakerSwitchToggled(_ sender: UISwitch) {
        toggleAudioRoute(toSpeaker: sender.isOn)
    }


    // MARK: AVAudioSession

    func toggleAudioRoute(toSpeaker: Bool) {
        // The mode set by the Voice SDK is "VoiceChat" so the default audio route is the built-in receiver. Use port override to switch the route.
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


    // MARK: Icon spinning

    func startSpin() {
        guard !isSpinning else { return }

        isSpinning = true
        spin(options: UIView.AnimationOptions.curveEaseIn)
    }

    func stopSpin() {
        isSpinning = false
    }

    func spin(options: UIView.AnimationOptions) {
        UIView.animate(withDuration: 0.5, delay: 0.0, options: options, animations: { [weak iconView] in
            if let iconView = iconView {
                iconView.transform = iconView.transform.rotated(by: CGFloat(Double.pi/2))
            }
        }) { [weak self] finished in
            guard let strongSelf = self else { return }

            if finished {
                if strongSelf.isSpinning {
                    strongSelf.spin(options: UIView.AnimationOptions.curveLinear)
                } else if options != UIView.AnimationOptions.curveEaseOut {
                    strongSelf.spin(options: UIView.AnimationOptions.curveEaseOut)
                }
            }
        }
    }
}


// MARK: - UITextFieldDelegate

@available(iOS 17.4, *)
extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        outgoingValue.resignFirstResponder()
        return true
    }
}


// MARK: - PushKitEventDelegate

@available(iOS 17.4, *)
extension ViewController: PushKitEventDelegate {
    func credentialsUpdated(credentials: PKPushCredentials) {
        guard
            (registrationRequired() || UserDefaults.standard.data(forKey: kCachedDeviceToken) != credentials.token)
        else {
            return
        }

        let cachedDeviceToken = credentials.token
        /*
         * Perform registration if a new device token is detected.
         */
        TwilioVoiceSDK.register(accessToken: accessToken, deviceToken: cachedDeviceToken) { error in
            if let error = error {
                NSLog("An error occurred while registering: \(error.localizedDescription)")
            } else {
                NSLog("Successfully registered for VoIP push notifications.")

                // Save the device token after successfully registered.
                UserDefaults.standard.set(cachedDeviceToken, forKey: kCachedDeviceToken)

                /**
                 * The TTL of a registration is 1 year. The TTL for registration for this device/identity
                 * pair is reset to 1 year whenever a new registration occurs or a push notification is
                 * sent to this device/identity pair.
                 */
                UserDefaults.standard.set(Date(), forKey: kCachedBindingDate)
            }
        }
    }

    /**
     * The TTL of a registration is 1 year. The TTL for registration for this device/identity pair is reset to
     * 1 year whenever a new registration occurs or a push notification is sent to this device/identity pair.
     * This method checks if binding exists in UserDefaults, and if half of TTL has been passed then the method
     * will return true, else false.
     */
    func registrationRequired() -> Bool {
        guard
            let lastBindingCreated = UserDefaults.standard.object(forKey: kCachedBindingDate)
        else { return true }

        let date = Date()
        var components = DateComponents()
        components.setValue(kRegistrationTTLInDays/2, for: .day)
        let expirationDate = Calendar.current.date(byAdding: components, to: lastBindingCreated as! Date)!

        if expirationDate.compare(date) == ComparisonResult.orderedDescending {
            return false
        }
        return true
    }

    func credentialsInvalidated() {
        guard let deviceToken = UserDefaults.standard.data(forKey: kCachedDeviceToken) else { return }

        TwilioVoiceSDK.unregister(accessToken: accessToken, deviceToken: deviceToken) { error in
            if let error = error {
                NSLog("An error occurred while unregistering: \(error.localizedDescription)")
            } else {
                NSLog("Successfully unregistered from VoIP push notifications.")
            }
        }

        UserDefaults.standard.removeObject(forKey: kCachedDeviceToken)
        UserDefaults.standard.removeObject(forKey: kCachedBindingDate)
    }

    func incomingPushReceived(payload: PKPushPayload) {
        TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
    }

    func incomingPushReceived(payload: PKPushPayload, completion: @escaping () -> Void) {
        TwilioVoiceSDK.handleNotification(payload.dictionaryPayload, delegate: self, delegateQueue: nil)
    }

    func incomingPushHandled() {
        guard let completion = incomingPushCompletionCallback else { return }
        incomingPushCompletionCallback = nil
        completion()
    }
}


// MARK: - TVONotificationDelegate

@available(iOS 17.4, *)
extension ViewController: NotificationDelegate {
    func callInviteReceived(callInvite: CallInvite) {
        NSLog("callInviteReceived:")

        UserDefaults.standard.set(Date(), forKey: kCachedBindingDate)

        let callerInfo: TVOCallerInfo = callInvite.callerInfo
        if let verified: NSNumber = callerInfo.verified {
            if verified.boolValue {
                NSLog("Call invite received from verified caller number!")
            }
        }

        let from = (callInvite.from ?? "Voice Bot").replacingOccurrences(of: "client:", with: "")

        // Always report to LiveCommunicationKit
        reportIncomingConversation(from: from, uuid: callInvite.uuid)
        activeCallInvites[callInvite.uuid.uuidString] = callInvite
    }

    func cancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite, error: Error) {
        NSLog("cancelledCallInviteCanceled:error:, error: \(error.localizedDescription)")

        guard let activeCallInvites = activeCallInvites, !activeCallInvites.isEmpty else {
            NSLog("No pending call invite")
            return
        }

        let callInvite = activeCallInvites.values.first { invite in invite.callSid == cancelledCallInvite.callSid }

        if let callInvite = callInvite {
            performEndConversationAction(uuid: callInvite.uuid)
            self.activeCallInvites.removeValue(forKey: callInvite.uuid.uuidString)
        }
    }
}


// MARK: - TVOCallDelegate

@available(iOS 17.4, *)
extension ViewController: CallDelegate {
    func callDidStartRinging(call: Call) {
        NSLog("callDidStartRinging:")

        placeCallButton.setTitle("Ringing", for: .normal)

        if playCustomRingback {
            playRingback()
        }
    }

    func callDidConnect(call: Call) {
        NSLog("callDidConnect:")

        if playCustomRingback {
            stopRingback()
        }

        if let conversationCompletionCallback = conversationCompletionCallback {
            conversationCompletionCallback(true)
        }

        // Tell the system the conversation is now connected. This is the LCK equivalent of
        // CXProvider.reportOutgoingCall(with:connectedAt:).
        if let uuid = call.uuid,
           let conversation = conversationManager.conversations.first(where: { $0.uuid == uuid }) {
            conversationManager.reportConversationEvent(.conversationConnected(Date()), for: conversation)
        }

        placeCallButton.setTitle("Hang Up", for: .normal)

        stopSpin()
        toggleAudioRoute(toSpeaker: true)
        toggleUIState(isEnabled: true, showCallControl: true)
    }

    func callIsReconnecting(call: Call, error: Error) {
        NSLog("call:isReconnectingWithError:")

        placeCallButton.setTitle("Reconnecting", for: .normal)

        toggleUIState(isEnabled: false, showCallControl: false)
    }

    func callDidReconnect(call: Call) {
        NSLog("callDidReconnect:")

        placeCallButton.setTitle("Hang Up", for: .normal)

        toggleUIState(isEnabled: true, showCallControl: true)
    }

    func callDidFailToConnect(call: Call, error: Error) {
        NSLog("Call failed to connect: \(error.localizedDescription)")

        if let completion = conversationCompletionCallback {
            completion(false)
        }

        if let uuid = call.uuid,
           let conversation = conversationManager.conversations.first(where: { $0.uuid == uuid }) {
            conversationManager.reportConversationEvent(.conversationEnded(Date(), .failed), for: conversation)
        }

        callDisconnected(call: call)
    }

    func callDidDisconnect(call: Call, error: Error?) {
        if let error = error {
            NSLog("Call failed: \(error.localizedDescription)")
        } else {
            NSLog("Call disconnected")
        }

        if !userInitiatedDisconnect {
            let reason: Conversation.EndedReason = (error != nil) ? .failed : .remoteEnded

            if let uuid = call.uuid,
               let conversation = conversationManager.conversations.first(where: { $0.uuid == uuid }) {
                conversationManager.reportConversationEvent(.conversationEnded(Date(), reason), for: conversation)
            }
        }

        callDisconnected(call: call)
    }

    func callDisconnected(call: Call) {
        if call == activeCall {
            activeCall = nil
        }

        activeCalls.removeValue(forKey: call.uuid!.uuidString)

        userInitiatedDisconnect = false

        if playCustomRingback {
            stopRingback()
        }

        stopSpin()

        if activeCalls.isEmpty {
            toggleUIState(isEnabled: true, showCallControl: false)
            placeCallButton.setTitle("Call", for: .normal)
        } else {
            toggleUIState(isEnabled: true, showCallControl: true)
        }
    }

    func callDidReceiveQualityWarnings(call: Call, currentWarnings: Set<NSNumber>, previousWarnings: Set<NSNumber>) {
        var warningsIntersection: Set<NSNumber> = currentWarnings
        warningsIntersection = warningsIntersection.intersection(previousWarnings)

        var newWarnings: Set<NSNumber> = currentWarnings
        newWarnings.subtract(warningsIntersection)
        if newWarnings.count > 0 {
            qualityWarningsUpdatePopup(newWarnings, isCleared: false)
        }

        var clearedWarnings: Set<NSNumber> = previousWarnings
        clearedWarnings.subtract(warningsIntersection)
        if clearedWarnings.count > 0 {
            qualityWarningsUpdatePopup(clearedWarnings, isCleared: true)
        }
    }

    func qualityWarningsUpdatePopup(_ warnings: Set<NSNumber>, isCleared: Bool) {
        var popupMessage: String = "Warnings detected: "
        if isCleared {
            popupMessage = "Warnings cleared: "
        }

        let mappedWarnings: [String] = warnings.map { number in warningString(Call.QualityWarning(rawValue: number.uintValue)!) }
        popupMessage += mappedWarnings.joined(separator: ", ")

        qualityWarningsToaster.alpha = 0.0
        qualityWarningsToaster.text = popupMessage
        UIView.animate(withDuration: 1.0, animations: {
            self.qualityWarningsToaster.isHidden = false
            self.qualityWarningsToaster.alpha = 1.0
        }) { [weak self] finish in
            guard let strongSelf = self else { return }
            let deadlineTime = DispatchTime.now() + .seconds(5)
            DispatchQueue.main.asyncAfter(deadline: deadlineTime, execute: {
                UIView.animate(withDuration: 1.0, animations: {
                    strongSelf.qualityWarningsToaster.alpha = 0.0
                }) { (finished) in
                    strongSelf.qualityWarningsToaster.isHidden = true
                }
            })
        }
    }

    func warningString(_ warning: Call.QualityWarning) -> String {
        switch warning {
        case .highRtt: return "high-rtt"
        case .highJitter: return "high-jitter"
        case .highPacketsLostFraction: return "high-packets-lost-fraction"
        case .lowMos: return "low-mos"
        case .constantAudioInputLevel: return "constant-audio-input-level"
        case .constantAudioOutputLevel: return "constant-audio-output-level"
        default: return "Unknown warning"
        }
    }


    // MARK: Ringtone

    func playRingback() {
        guard let path = Bundle.main.path(forResource: "ringtone", ofType: "wav") else { return }
        let ringtonePath = URL(fileURLWithPath: path)

        do {
            ringtonePlayer = try AVAudioPlayer(contentsOf: ringtonePath)
            ringtonePlayer?.delegate = self
            ringtonePlayer?.numberOfLoops = -1

            ringtonePlayer?.volume = 1.0
            ringtonePlayer?.play()
        } catch {
            NSLog("Failed to initialize audio player")
        }
    }

    func stopRingback() {
        guard let ringtonePlayer = ringtonePlayer, ringtonePlayer.isPlaying else { return }

        ringtonePlayer.stop()
    }
}


// MARK: - ConversationManagerDelegate

@available(iOS 17.4, *)
extension ViewController: ConversationManagerDelegate {

    func conversationManagerDidBegin(_ manager: ConversationManager) {
        NSLog("conversationManagerDidBegin")
    }

    func conversationManagerDidReset(_ manager: ConversationManager) {
        NSLog("conversationManagerDidReset")
        audioDevice.isEnabled = false
    }

    func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession) {
        NSLog("conversationManager:didActivateAudioSession:")
        audioDevice.isEnabled = true
    }

    func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession) {
        NSLog("conversationManager:didDeactivateAudioSession:")
        audioDevice.isEnabled = false
    }

    func conversationManager(_ manager: ConversationManager, conversationChanged conversation: Conversation) {
        // The Conversation.State transitions (.idle / .joining / .joined / .paused / .leaving / .left)
        // are reported here. This example drives UI from CallDelegate callbacks instead, so we just log.
        NSLog("conversationManager:conversationChanged: state=\(conversation.state)")
    }

    func conversationManager(_ manager: ConversationManager, timedOutPerforming action: ConversationAction) {
        NSLog("conversationManager:timedOutPerformingAction: \(type(of: action))")
    }

    /*
     * Unlike CallKit, which has a dedicated delegate method per action type, LiveCommunicationKit
     * delivers every action through a single callback. Switch on the concrete subclass to dispatch.
     */
    func conversationManager(_ manager: ConversationManager, perform action: ConversationAction) {
        switch action {
        case let action as StartConversationAction:
            NSLog("conversationManager:perform:StartConversationAction")
            toggleUIState(isEnabled: false, showCallControl: false)
            startSpin()

            if let conversation = manager.conversations.first(where: { $0.uuid == action.conversationUUID }) {
                manager.reportConversationEvent(.conversationStartedConnecting(Date()), for: conversation)
            }

            performVoiceCall(uuid: action.conversationUUID, client: "") { success in
                if success {
                    NSLog("performVoiceCall() successful")
                    action.fulfill(dateStarted: Date())
                } else {
                    NSLog("performVoiceCall() failed")
                }
            }

        case let action as JoinConversationAction:
            NSLog("conversationManager:perform:JoinConversationAction")
            performAnswerVoiceCall(uuid: action.conversationUUID) { success in
                if success {
                    NSLog("performAnswerVoiceCall() successful")
                    action.fulfill(dateConnected: Date())
                } else {
                    NSLog("performAnswerVoiceCall() failed")
                }
            }

        case let action as EndConversationAction:
            NSLog("conversationManager:perform:EndConversationAction")
            if let invite = activeCallInvites[action.conversationUUID.uuidString] {
                invite.reject()
                activeCallInvites.removeValue(forKey: action.conversationUUID.uuidString)
            } else if let call = activeCalls[action.conversationUUID.uuidString] {
                call.disconnect()
            } else {
                NSLog("Unknown UUID to perform end action with")
            }
            action.fulfill(dateEnded: Date())

        case let action as MuteConversationAction:
            NSLog("conversationManager:perform:MuteConversationAction")
            if let call = activeCalls[action.conversationUUID.uuidString] {
                call.isMuted = action.isMuted
            }

        case let action as PauseConversationAction:
            // The CallKit equivalent is CXSetHeldCallAction. LiveCommunicationKit names it Pause and
            // exposes the desired state via `isPaused`.
            NSLog("conversationManager:perform:PauseConversationAction")
            if let call = activeCalls[action.conversationUUID.uuidString] {
                call.isOnHold = action.isPaused

                /*
                 * Workaround for an iOS issue where didActivate is not called when a call is unheld
                 * after an interrupting call ended remotely.
                 * https://developer.apple.com/forums/thread/694836
                 */
                if !action.isPaused {
                    audioDevice.isEnabled = true
                    activeCall = call
                }

                toggleUIState(isEnabled: true, showCallControl: true)
            }

        case let action as PlayToneAction:
            NSLog("conversationManager:perform:PlayToneAction")
            if let call = activeCalls[action.conversationUUID.uuidString] {
                call.sendDigits(action.digits)
            }

        default:
            NSLog("Unhandled action: \(type(of: action))")
        }
    }


    // MARK: ConversationManager actions

    func performStartConversationAction(uuid: UUID, handle: String) {
        let lckHandle = Handle(type: .generic, value: handle, displayName: handle)
        let action = StartConversationAction(conversationUUID: uuid, handles: [lckHandle], isVideo: false)

        Task {
            do {
                try await conversationManager.perform([action])
                NSLog("StartConversationAction request successful")
            } catch {
                NSLog("StartConversationAction request failed: \(error.localizedDescription)")
            }
        }
    }

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
                try await conversationManager.reportNewIncomingConversation(uuid: uuid, update: update)
                NSLog("Incoming conversation successfully reported.")
            } catch {
                NSLog("Failed to report incoming conversation: \(error.localizedDescription).")
            }
        }
    }

    func performEndConversationAction(uuid: UUID) {
        let action = EndConversationAction(conversationUUID: uuid)

        Task {
            do {
                try await conversationManager.perform([action])
                NSLog("EndConversationAction request successful")
            } catch {
                NSLog("EndConversationAction request failed: \(error.localizedDescription).")
            }
        }
    }

    func performVoiceCall(uuid: UUID, client: String?, completionHandler: @escaping (Bool) -> Void) {
        let connectOptions = ConnectOptions(accessToken: accessToken) { builder in
            builder.params = [twimlParamTo: self.outgoingValue.text ?? ""]
            builder.uuid = uuid
        }

        let call = TwilioVoiceSDK.connect(options: connectOptions, delegate: self)
        activeCall = call
        activeCalls[call.uuid!.uuidString] = call
        conversationCompletionCallback = completionHandler
    }

    func performAnswerVoiceCall(uuid: UUID, completionHandler: @escaping (Bool) -> Void) {
        guard let callInvite = activeCallInvites[uuid.uuidString] else {
            NSLog("No CallInvite matches the UUID")
            return
        }

        let acceptOptions = AcceptOptions(callInvite: callInvite) { builder in
            builder.uuid = callInvite.uuid
        }

        let call = callInvite.accept(options: acceptOptions, delegate: self)
        activeCall = call
        activeCalls[call.uuid!.uuidString] = call
        conversationCompletionCallback = completionHandler

        activeCallInvites.removeValue(forKey: uuid.uuidString)
    }
}


// MARK: - AVAudioPlayerDelegate

@available(iOS 17.4, *)
extension ViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            NSLog("Audio player finished playing successfully")
        } else {
            NSLog("Audio player finished playing with some error")
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            NSLog("Decode error occurred: \(error.localizedDescription)")
        }
    }
}
