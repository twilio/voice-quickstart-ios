source 'https://github.com/CocoaPods/Specs.git'

workspace 'VoiceQuickstart'

abstract_target 'TwilioVoice' do
  pod 'TwilioVoice', '~> 5.4.1'
  use_frameworks!
  
  target 'SwiftVoiceQuickstart' do
    platform :ios, '10.0'
    project 'SwiftVoiceQuickstart.xcproject'
  end

  target 'ObjCVoiceQuickstart' do
    platform :ios, '10.0'
    project 'ObjCVoiceQuickstart.xcproject'
  end

  target 'AudioDeviceExample' do
    platform :ios, '11.0'
    project 'AudioDeviceExample.xcproject'
  end
end
