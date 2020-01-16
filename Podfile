source 'https://github.com/CocoaPods/Specs.git'

workspace 'SwiftVoiceQuickstart'

abstract_target 'TwilioVoice' do
  pod 'TwilioVoice', '~> 5.1.1'
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
