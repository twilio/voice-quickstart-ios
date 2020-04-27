## Managing Audio Interruptions

Different versions of iOS deal with **AVAudioSession** interruptions sightly differently. This section documents how the Programmable Voice iOS SDK manages audio interruptions and resumes call audio after the interruption ends. There are currently some cases that the SDK cannot resume call audio automatically because iOS does not provide the necessary notifications to indicate that the interruption has ended.

### How Programmable Voice iOS SDK handles audio interruption
- The `TVOCall` object registers itself as an observer of `AVAudioSessionInterruptionNotification` when it's created.
- When the notification is fired and the interruption type is `AVAudioSessionInterruptionTypeBegan`, the `TVOCall` object automatically disables both the local and remote audio tracks.
- When the SDK receives the notification with `AVAudioSessionInterruptionTypeEnded`, it re-enables the local and remote audio tracks and resumes the audio of active Calls.
  - We have noticed that on iOS 8 and 9, the interruption notification with `AVAudioSessionInterruptionTypeEnded` is not always fired therefore the SDK is not able to resume call audio automatically. This is a known issue and an alternative way is to use the `UIApplicationDidBecomeActiveNotification` and resume audio when the app is active again after the interruption.

### Notifications in different iOS versions
Below is a table listing the system notifications received with different steps to trigger audio interruptions and resume during an active Voice SDK call. (Assume the app is in an active Voice SDK call)

|Scenario|Notification of interruption-begins|Notification of interruption-ends|Call audio resumes?|Note|
|---|---|---|---|---|
|PSTN Interruption|
|A.<br>PSTN interruption<br>Accept the PSTN incoming call<br>Remote party of PSTN call hangs up|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|B.<br>PSTN interruption<br>Accept the PSTN incoming call<br>Local party of PSTN call hangs up|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|C.<br>PSTN interruption<br>Reject PSTN|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|D.<br>PSTN interruption<br>Ignore PSTN|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|E.<br>PSTN interruption<br>Remote party of PSTN call hangs up before local party can answer|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|Other Types of Audio Interruption<br>(YouTube app as example)|
|F.<br>Switch to YouTube app and play video<br>Stop the video<br>Switch back to Voice app|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:x: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:x: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|Interruption-ended notification is not fired on iOS 9.<br>Interruption-ended notification is not fired until few seconds after switching back to the Voice app on iOS 10/11.<br>The `AVAudioSessionInterruptionOptionShouldResume` flag is `false`.|
|G.<br>Switch to YouTube app and play video<br>Switch back to Voice app without stopping the video|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:x: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:x: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|Interruption-ended notification is not fired on iOS 9.<br>Interruption-ended notification is not fired until few seconds after switching back to the Voice app on iOS 10/11.<br>The `AVAudioSessionInterruptionOptionShouldResume` flag is `false`.|
|H.<br>Switch to YouTube app and play video<br>Double-press Home button and terminate YouTube app<br>Back to Voice app|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|:white_check_mark: iOS 9<br>:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|Interruption-ended notification is not fired until the Voice app is back to the active state.<br>The `AVAudioSessionInterruptionOptionShouldResume` flag is `false`.|

### CallKit
On iOS 10 and later, CallKit (if integrated) takes care of the interruption by providing a set of delegate methods so that the application can respond with proper audio device handling and state transitioning in order to ensure call audio works after the interruption has ended.

#### Notifications & Callbacks during Interruption
By enabling the `supportsHolding` flag of the `CXCallUpdate` object when reporting a call to the CallKit framework, you will see the **"Hold & Accept"** option when there is another PSTN or CallKit-enabled call. By pressing the **"Hold & Accept"** option, a series of things and callbacks will happen:

1. The `provider:performSetHeldCallAction:` delegate method is called with `CXSetHeldCallAction.isOnHold = YES`. Put the Voice call on-hold here and fulfill the action.
2. The `AVAudioSessionInterruptionNotification` notification is fired to indicate the AVAudioSession interruption has started.
3. CallKit will deactivate the AVAudioSession of your app and fire the `provider:didDeactivateAudioSession:` callback.
4. When the interrupting call ends, instead of getting the `AVAudioSessionInterruptionNotification` notification, the system will notify that you can resume the call audio that was put on-hold when the interruption began by calling the `provider:performSetHeldCallAction:` method again. **Note** that this callback is not fired if the interrupting call is disconnected by the remote party.
5. The AVAudioSession of the app will be activated again and you should re-enable the audio device of the SDK `TwilioVoice.audioDevice.enabled = YES` in the `provider:didActivateAudioSession:` method.

|Scenario|Audio resumes after interrupion?|Note|
|---|---|---|
|A.<br>Hold & Accept<br>Hang up PSTN interruption on the local end|:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|B.<br>Hold & Accept<br>Remote party hangs up PSTN interruption|:x: iOS 10<br>:x: iOS 11|`provider:performSetHeldCallAction:` not called after the interruption ends.|
|C.<br>Hold & Accept<br>Switch back to the Voice Call on system UI|:white_check_mark: iOS 10<br>:white_check_mark: iOS 11| |
|D.<br>Reject|:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|No actual audio interruption happened since the interrupting call is not answered|
|E.<br>Ignore|:white_check_mark: iOS 10<br>:white_check_mark: iOS 11|No actual audio interruption happened since the interrupting call is not answered|

In case 2, CallKit does not automatically resume call audio by calling `provider:performSetHeldCallAction:` method, but the system UI will show that the Voice call is still on-hold. You can resume the call using the **"Hold"** button, or use the `CXSetHeldCallAction` to lift the on-hold state programmatically. The app is also responsible of updating UI state to indicate the "hold" state of the call to avoid user confusion.

```.objc
// Resume call audio programmatically after interruption
CXSetHeldCallAction *setHeldCallAction = [[CXSetHeldCallAction alloc] initWithCallUUID:self.call.uuid onHold:holdSwitch.on];
CXTransaction *transaction = [[CXTransaction alloc] initWithAction:setHeldCallAction];
[self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
    if (error) {
        NSLog(@"Failed to submit set-call-held transaction request");
    } else {
        NSLog(@"Set-call-held transaction successfully done");
    }
}];
```