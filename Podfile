source 'https://github.com/CocoaPods/Specs.git'

workspace 'VoiceQuickstart'

abstract_target 'TwilioVoice' do
  pod 'TwilioVoice', '~> 5.3.0'
  use_frameworks!
  
  target 'SwiftVoiceQuickstart' do
    platform :ios, '10.0'
    project 'SwiftVoiceQuickstart.xcproject'
  end

  target 'ObjCVoiceQuickstart' do
    platform :ios, '10.0'
    project 'ObjCVoiceQuickstart.xcproject'
  end
end
