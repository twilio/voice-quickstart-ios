//
//  ViewController.swift
//  Twilio Voice Quickstart - LiveCommunicationKit
//
//  Copyright © Twilio, Inc. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var placeCallButton: UIButton!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var outgoingValue: UITextField!
    @IBOutlet weak var callControlView: UIView!
    @IBOutlet weak var muteSwitch: UISwitch!
    @IBOutlet weak var speakerSwitch: UISwitch!

    private var isSpinning: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        toggleUIState(isEnabled: true, showCallControl: false)
        outgoingValue.delegate = self
        CallManager.shared.delegate = self
    }

    // MARK: UI helpers

    private func toggleUIState(isEnabled: Bool, showCallControl: Bool) {
        placeCallButton.isEnabled = isEnabled

        if showCallControl {
            callControlView.isHidden = false
            muteSwitch.isOn = CallManager.shared.getActiveCall()?.isMuted ?? false
            for output in AVAudioSession.sharedInstance().currentRoute.outputs {
                speakerSwitch.isOn = output.portType == AVAudioSession.Port.builtInSpeaker
            }
        } else {
            callControlView.isHidden = true
        }
    }

    private func showMicrophoneAccessRequest(recipient: String) {
        let alertController = UIAlertController(title: "Voice Quick Start",
                                                message: "Microphone permission not granted",
                                                preferredStyle: .alert)

        let continueWithoutMic = UIAlertAction(title: "Continue without microphone", style: .default) { _ in
            CallManager.shared.startCall(to: recipient)
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

    // MARK: Actions

    @IBAction func mainButtonPressed(_ sender: Any) {
        if (CallManager.shared.getActiveCall() != nil) {
            CallManager.shared.endActiveCall()
            return
        }

        let recipient = outgoingValue.text ?? ""
        checkRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    CallManager.shared.startCall(to: recipient)
                } else {
                    self?.showMicrophoneAccessRequest(recipient: recipient)
                }
            }
        }
    }

    @IBAction func muteSwitchToggled(_ sender: UISwitch) {
        CallManager.shared.toggleMute(sender.isOn)
    }

    @IBAction func speakerSwitchToggled(_ sender: UISwitch) {
        CallManager.shared.toggleAudioRoute(toSpeaker: sender.isOn)
    }

    private func checkRecordPermission(completion: @escaping (_ permissionGranted: Bool) -> Void) {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: completion(true)
        case .denied:  completion(false)
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in completion(granted) }
        @unknown default:
            completion(false)
        }
    }

    // MARK: Icon spinning

    private func startSpin() {
        guard !isSpinning else { return }
        isSpinning = true
        spin(options: UIView.AnimationOptions.curveEaseIn)
    }

    private func stopSpin() {
        isSpinning = false
    }

    private func spin(options: UIView.AnimationOptions) {
        UIView.animate(withDuration: 0.5, delay: 0.0, options: options, animations: { [weak iconView] in
            if let iconView = iconView {
                iconView.transform = iconView.transform.rotated(by: CGFloat(Double.pi/2))
            }
        }) { [weak self] finished in
            guard let strongSelf = self, finished else { return }
            if strongSelf.isSpinning {
                strongSelf.spin(options: UIView.AnimationOptions.curveLinear)
            } else if options != UIView.AnimationOptions.curveEaseOut {
                strongSelf.spin(options: UIView.AnimationOptions.curveEaseOut)
            }
        }
    }
}


// MARK: - UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        outgoingValue.resignFirstResponder()
        return true
    }
}

// MARK: - CallManagerDelegate

extension ViewController: CallManagerDelegate {

    func callManager(_ manager: CallManager, didChangeState state: CallState) {
        switch state {
        case .idle:
            stopSpin()
            placeCallButton.setTitle("Call", for: .normal)
            toggleUIState(isEnabled: true, showCallControl: false)
        case .connecting:
            startSpin()
            toggleUIState(isEnabled: false, showCallControl: false)
        case .ringing:
            placeCallButton.setTitle("Ringing", for: .normal)
        case .connected:
            stopSpin()
            placeCallButton.setTitle("Hang Up", for: .normal)
            toggleUIState(isEnabled: true, showCallControl: true)
        case .reconnecting:
            placeCallButton.setTitle("Reconnecting", for: .normal)
            toggleUIState(isEnabled: false, showCallControl: false)
        case .disconnected:
            stopSpin()
            placeCallButton.setTitle("Call", for: .normal)
            toggleUIState(isEnabled: true, showCallControl: false)
        }
    }
}
