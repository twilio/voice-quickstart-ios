# Twilio Programmable Voice for iOS

This repository contains releases for the Twilio Programmable Voice for iOS SDK. These releases can be installed using Swift Package Manager, CocoaPods or manually, as you prefer.

### Swift Package Manager

You can add Programmable Voice for iOS by adding the `https://github.com/twilio/twilio-voice-ios` repository as a Swift Package. 

In your *Build Settings*, you will also need to modify `Other Linker Flags` to include `-ObjC`.

As of the latest release of Xcode (currently 12.4), there is a [known issue](https://bugs.swift.org/browse/SR-13343) with consuming binary frameworks distributed via Swift Package Manager. The current workaround to this issue is to add a `Run Script Phase` to the `Build Phases` of your Xcode project. This `Run Script Phase` should come **after** the `Embed Frameworks` build phase. This new `Run Script Phase` should contain the following code:

```sh
find "${CODESIGNING_FOLDER_PATH}" -name '*.framework' -print0 | while read -d $'\0' framework
do
    codesign --force --deep --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --preserve-metadata=identifier,entitlements --timestamp=none "${framework}"
done

```
    
### CocoaPods

It's easy to install the Voice framework if you manage your dependencies using [CocoaPods](http://cocoapods.org). Simply add the following to your `Podfile`:

~~~.rb
source 'https://github.com/cocoapods/specs'

target 'TARGET_NAME' do
  use_frameworks!

  pod 'TwilioVoice', '~> 6.2.0'
end
~~~

Then run `pod install --verbose` to install the dependencies to your project.

### Manual Integration

See [manual installation](https://www.twilio.com/docs/voice/voip-sdk/ios#manual-install).

### Carthage Integration

Carthage is not currently a supported distribution mechanism for Twilio Voice. Carthage does not currently work with `.xcframeworks` as documented [here](https://github.com/Carthage/Carthage/issues/2890). Once Carthage supports binary `.xcframeworks`, Carthage distribution will be re-added.

## Issues and Support

Please file any issues you find here on Github.
Please ensure that you are not sharing any
[Personally Identifiable Information(PII)](https://www.twilio.com/docs/glossary/what-is-personally-identifiable-information-pii)
or sensitive account information (API keys, credentials, etc.) when reporting an issue.

For general inquiries related to the Voice SDK you can file a [support ticket](https://support.twilio.com/hc/en-us/requests/new).

## License

Twilio Programmable Voice for iOS is distributed under [TWILIO-TOS](https://www.twilio.com/legal/tos).
