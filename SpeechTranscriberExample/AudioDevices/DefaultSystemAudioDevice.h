//
//  DefaultSystemAudioDevice.h
//

#import <Foundation/Foundation.h>

@import TwilioVoice;

/**
 A very small, "just the basics" audio device which implements the TVOAudioDevice protocol,
 that captures from the built-in mic and renders to the system output using RemoteIO.
 */
@interface DefaultSystemAudioDevice : NSObject <TVOAudioDevice>

@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

@property (nonatomic, nonnull, strong) void(^renderProcessingCallback)(AVAudioPCMBuffer * _Nonnull buffer, AVAudioFormat * _Nonnull format);
@property (nonatomic, nonnull, strong) void(^inputProcessingCallback)(AudioBufferList * _Nonnull ioData);

+ (nullable TVOAudioFormat *)activeFormat;

@end
