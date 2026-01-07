//
//  DefaultSystemAudioDevice.h
//  ObjCVoiceQuickstart
//
//

#import <Foundation/Foundation.h>
@import AVFoundation;
@import AudioToolbox;
@import TwilioVoice;

/**
 A very small, “just the basics” audio device that captures from the built-in mic
 and renders to the system output using RemoteIO. It implements TVOAudioDevice.
 */
@interface DefaultSystemAudioDevice : NSObject <TVOAudioDevice>

@property (nonatomic, strong) void(^renderProcessingCallback)(AVAudioPCMBuffer *buffer, AVAudioFormat *format);
@property (nonatomic, strong) void(^inputProcessingCallback)(AudioBufferList *ioData);

+ (nullable TVOAudioFormat *)activeFormat;

@end
