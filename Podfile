source 'https://github.com/CocoaPods/Specs.git'

workspace 'SwiftVoiceQuickstart'

abstract_target 'TwilioVoice' do
  pod 'TwilioVoice', '~> 2.0.0'
  use_frameworks!

  target 'SwiftVoiceQuickstart' do
    platform :ios, '8.1'
    project 'SwiftVoiceQuickstart.xcproject'
  end
  
  target 'SwiftVoiceCallKitQuickstart' do
    platform :ios, '10.0'
    project 'SwiftVoiceCallKitQuickstart.xcproject'
  end
end
