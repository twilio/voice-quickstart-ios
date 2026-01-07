//
//  DefaultSystemAudioDevice.m
//  ObjCVoiceQuickstart
//

#import "DefaultSystemAudioDevice.h"

static const NSTimeInterval kPreferredIOBufferDuration = 0.01; // ~10 ms

// This is the maximum slice size for VoiceProcessingIO (as observed in the field). We will double check at initialization time.
static size_t kMaximumFramesPerBuffer = 3072;

// We will use mono playback and recording where available.
static size_t const kPreferredNumberOfChannels = 1;

// Forward declarations of our Audio Unit callbacks
static OSStatus RenderCallback(void                       *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp       *inTimeStamp,
                               UInt32                      inBusNumber,
                               UInt32                      inNumberFrames,
                               AudioBufferList            *ioData);

static OSStatus InputCallback(void                        *inRefCon,
                              AudioUnitRenderActionFlags  *ioActionFlags,
                              const AudioTimeStamp        *inTimeStamp,
                              UInt32                       inBusNumber,
                              UInt32                       inNumberFrames,
                              AudioBufferList             *ioData);

// Audio renderer contexts used in core audio's playout callback to retrieve the sdk's audio device context.
typedef struct AudioRendererContext {
    // Audio device context received in AudioDevice's `startRendering:context` callback.
    TVOAudioDeviceContext deviceContext;

    // Maximum frames per buffer.
    size_t maxFramesPerBuffer;

    // Buffer passed to AVAudioEngine's manualRenderingBlock to receive the mixed audio data.
    AudioBufferList *bufferList;

    /*
     * Points to AVAudioEngine's manualRenderingBlock. This block is called from within the VoiceProcessingIO playout
     * callback in order to receive mixed audio data from AVAudioEngine in real time.
     */
    void *renderBlock;
} AudioRendererContext;

// Audio renderer contexts used in core audio's record callback to retrieve the sdk's audio device context.
typedef struct AudioCapturerContext {
    // Audio device context received in AudioDevice's `startCapturing:context` callback.
    TVOAudioDeviceContext deviceContext;

    // Preallocated buffer list. Please note the buffer itself will be provided by Core Audio's VoiceProcessingIO audio unit.
    AudioBufferList *bufferList;

    // Preallocated mixed (AudioUnit mic + AVAudioPlayerNode file) audio buffer list.
    AudioBufferList *mixedAudioBufferList;

    // Core Audio's VoiceProcessingIO audio unit.
    AudioUnit audioUnit;

    /*
     * Points to AVAudioEngine's manualRenderingBlock. This block is called from within the VoiceProcessingIO playout
     * callback in order to receive mixed audio data from AVAudioEngine in real time.
     */
    void *renderBlock;
} AudioCapturerContext;

AudioComponentInstance _rioUnit;
BOOL _rendering;
BOOL _capturing;
void *_captureScratch;
size_t _captureScratchBytes;

@interface DefaultSystemAudioDevice ()

// Twilio formats & contexts
@property (nonatomic, strong) TVOAudioFormat *renderingFormat;
@property (nonatomic, strong) TVOAudioFormat *capturingFormat;
@property (nonatomic, assign) AudioRendererContext *renderingContext;
@property (nonatomic, assign) AudioCapturerContext *capturingContext;
@property (nonatomic, assign) AudioBufferList captureBufferList;

@end

@implementation DefaultSystemAudioDevice {
    BOOL _ioRunning;
}

- (instancetype)init {
    self = [super init];

    if (self) {
        /*
         * Initialize rendering and capturing context. The deviceContext will be be filled in when startRendering or
         * startCapturing gets called.
         */

        // Initialize the rendering context
        self.renderingContext = malloc(sizeof(AudioRendererContext));
        memset(self.renderingContext, 0, sizeof(AudioRendererContext));

        // Initialize the capturing context
        self.capturingContext = malloc(sizeof(AudioCapturerContext));
        memset(self.capturingContext, 0, sizeof(AudioCapturerContext));
        self.capturingContext->bufferList = &_captureBufferList;
    }

    return self;
}

// MARK: - TVOAudioDeviceRenderer

- (nullable TVOAudioFormat *)renderFormat {
    if (!_renderingFormat) {

        /*
         * Assume that the AVAudioSession has already been configured and started and that the values
         * for sampleRate and IOBufferDuration are final.
         */
        _renderingFormat = [[self class] activeFormat];
        self.renderingContext->maxFramesPerBuffer = _renderingFormat.framesPerBuffer;
    }

    return _renderingFormat;
}

- (BOOL)initializeRenderer {
    // Configure AVAudioSession for duplex VoIP
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    // Category / mode recommended for VoIP
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:(AVAudioSessionCategoryOptionAllowBluetoothHFP |
                          AVAudioSessionCategoryOptionAllowBluetoothA2DP |
                          AVAudioSessionCategoryOptionDefaultToSpeaker)
                   error:&error];

    [session setMode:AVAudioSessionModeVoiceChat error:&error];
    [session setPreferredIOBufferDuration:kPreferredIOBufferDuration error:&error];

    // Choose sample rate supported by device and Twilio (16/44.1/48 kHz etc.)
    double sr = session.sampleRate > 0.0 ? session.sampleRate : 48000.0;
    [session setPreferredSampleRate:sr error:&error];

    // Build a 16-bit LPCM format description Twilio expects
//    const uint32_t sampleRate = (uint32_t)round([session sampleRate]);
//    const size_t framesPerBuffer = (size_t)lrint(sampleRate * kPreferredIOBufferDuration);
//    self.renderingFormat  = [[TVOAudioFormat alloc] initWithChannels:1
//                                                          sampleRate:sampleRate
//                                                     framesPerBuffer:framesPerBuffer];
//    return (self.renderingFormat != nil);
    return YES;
}

- (BOOL)startRendering:(TVOAudioDeviceContext)context {
    self.renderingContext->deviceContext = context;
    _rendering = YES;
    return [self startIOIfNeeded];
}

- (BOOL)stopRendering {
    _rendering = NO;
    self.renderingContext->deviceContext= NULL;
    return [self stopIOIfPossible];
}

// MARK: - TVOAudioDeviceCapturer

- (nullable TVOAudioFormat *)captureFormat {
    if (!_capturingFormat) {

        /*
         * Assume that the AVAudioSession has already been configured and started and that the values
         * for sampleRate and IOBufferDuration are final.
         */
        _capturingFormat = [[self class] activeFormat];
    }

    return _capturingFormat;
}

- (BOOL)initializeCapturer {
    _captureBufferList.mNumberBuffers = 1;
    _captureBufferList.mBuffers[0].mNumberChannels = kPreferredNumberOfChannels;

    // Capture should mirror render for simple full-duplex
    if (!self.renderingFormat) {
        // If renderer hasn’t been initialized, pick a safe default
        AVAudioSession *session = [AVAudioSession sharedInstance];
        double sr = session.sampleRate > 0.0 ? session.sampleRate : 48000.0;
        const uint32_t sampleRate = (uint32_t)round(sr);
        const size_t framesPerBuffer = (size_t)lrint(sampleRate * kPreferredIOBufferDuration);
        self.renderingFormat = [[TVOAudioFormat alloc] initWithChannels:1
                                                             sampleRate:sampleRate
                                                        framesPerBuffer:framesPerBuffer];
    }
    self.capturingFormat = [[TVOAudioFormat alloc] initWithChannels:self.renderingFormat.numberOfChannels
                                                         sampleRate:self.renderingFormat.sampleRate
                                                    framesPerBuffer:self.renderingFormat.framesPerBuffer];
    return (self.capturingFormat != nil);
}

- (BOOL)startCapturing:(TVOAudioDeviceContext)context {
    self.capturingContext->deviceContext = context;
    _capturing = YES;

    // Allocate one scratch buffer large enough for the max mic pull
    _captureScratchBytes = self.capturingFormat.bufferSize;
    _captureScratch = malloc(_captureScratchBytes);

    return [self startIOIfNeeded];
}

- (BOOL)stopCapturing {
    _capturing = NO;
    self.capturingContext->deviceContext = NULL;

    if (_captureScratch) { free(_captureScratch); _captureScratch = NULL; }
    _captureScratchBytes = 0;

    return [self stopIOIfPossible];
}

// MARK: - RemoteIO lifecycle

- (BOOL)startIOIfNeeded {
    if (_ioRunning) return YES;

    // Activate session when starting I/O
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setActive:YES error:&error];

    if (_rioUnit == NULL) {
        if (![self createAndConfigureRemoteIO]) return NO;
    }

    OSStatus s = AudioOutputUnitStart(_rioUnit);
    if (s == noErr) {
        _ioRunning = YES;
        return YES;
    }
    return NO;
}

- (BOOL)stopIOIfPossible {
    if (!_ioRunning) return YES;

    if (!_rendering && !_capturing) {
        AudioOutputUnitStop(_rioUnit);
        _ioRunning = NO;
        // Keep unit alive to avoid churn; comment next line to fully tear down.
        // [self destroyRemoteIO];
        [[AVAudioSession sharedInstance] setActive:NO error:nil];
    }
    return YES;
}

- (BOOL)createAndConfigureRemoteIO {
    // Create
    AudioComponentDescription desc = {0};
    desc.componentType         = kAudioUnitType_Output;
    desc.componentSubType      = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;

    AudioComponent comp = AudioComponentFindNext(NULL, &desc);
    if (!comp) return NO;
    if (AudioComponentInstanceNew(comp, &_rioUnit) != noErr) return NO;

    // Enable both I/O sides
    UInt32 one = 1;
    AudioUnitSetProperty(_rioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Input,   1, &one, sizeof(one)); // mic in on bus 1
    AudioUnitSetProperty(_rioUnit,
                         kAudioOutputUnitProperty_EnableIO,
                         kAudioUnitScope_Output,  0, &one, sizeof(one)); // speaker out on bus 0

    // Set formats (16-bit LPCM, mono)
    AudioStreamBasicDescription renderASBD  = [self.renderingFormat streamDescription];
    AudioStreamBasicDescription captureASBD = [self.capturingFormat streamDescription];

    // Playback: app feeds data into RemoteIO input scope / bus 0
    AudioUnitSetProperty(_rioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Input, 0,
                         &renderASBD, sizeof(renderASBD));

    // Capture: RemoteIO produces data on output scope / bus 1
    AudioUnitSetProperty(_rioUnit,
                         kAudioUnitProperty_StreamFormat,
                         kAudioUnitScope_Output, 1,
                         &captureASBD, sizeof(captureASBD));

    // Install callbacks
    AURenderCallbackStruct renderCb = { .inputProc = RenderCallback, .inputProcRefCon = (__bridge void *)self };
    AudioUnitSetProperty(_rioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Global, 0,
                         &renderCb, sizeof(renderCb));

    AURenderCallbackStruct inputCb  = { .inputProc = InputCallback,  .inputProcRefCon  = (__bridge void *)self };
    AudioUnitSetProperty(_rioUnit,
                         kAudioOutputUnitProperty_SetInputCallback,
                         kAudioUnitScope_Global, 1,
                         &inputCb, sizeof(inputCb));

    // Initialize
    OSStatus s = AudioUnitInitialize(_rioUnit);
    return (s == noErr);
}

- (void)destroyRemoteIO {
    if (_rioUnit) { AudioUnitUninitialize(_rioUnit); AudioComponentInstanceDispose(_rioUnit); _rioUnit = NULL; }
}

+ (nullable TVOAudioFormat *)activeFormat {
    /*
     * Use the pre-determined maximum frame size. AudioUnit callbacks are variable, and in most sitations will be close
     * to the `AVAudioSession.preferredIOBufferDuration` that we've requested.
     */
    const size_t sessionFramesPerBuffer = kMaximumFramesPerBuffer;
    const double sessionSampleRate = 16000; //[AVAudioSession sharedInstance].sampleRate;

    return [[TVOAudioFormat alloc] initWithChannels:TVOAudioChannelsMono
                                         sampleRate:sessionSampleRate
                                    framesPerBuffer:sessionFramesPerBuffer];
}

// MARK: - Dealloc

- (void)dealloc {
    [self destroyRemoteIO];
    if (_captureScratch) free(_captureScratch);
}

@end

#pragma mark - Audio Unit Callbacks

static OSStatus RenderCallback(void                       *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp       *inTimeStamp,
                               UInt32                      inBusNumber,
                               UInt32                      inNumberFrames,
                               AudioBufferList            *ioData)
{
    DefaultSystemAudioDevice *self = (__bridge DefaultSystemAudioDevice *)inRefCon;
    if (!self || !_rendering || self.renderingContext->deviceContext == NULL) {
        // Output silence if we’re not ready
        for (UInt32 i = 0; i < ioData->mNumberBuffers; ++i) {
            memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
        }
        return noErr;
    }

    // Twilio expects signed 16-bit LPCM. Pull exactly the bytes CoreAudio asks for.
    for (UInt32 i = 0; i < ioData->mNumberBuffers; ++i) {
        size_t bytes = ioData->mBuffers[i].mDataByteSize;
        TVOAudioDeviceReadRenderData(self.renderingContext->deviceContext,
                                     (int8_t *)ioData->mBuffers[i].mData,
                                     bytes);
    }

    const AudioStreamBasicDescription asbd = [[[DefaultSystemAudioDevice class] activeFormat] streamDescription];
    AVAudioFormat *format = [[AVAudioFormat alloc] initWithStreamDescription:&asbd];
    
    AVAudioPCMBuffer *buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format
                                                          bufferListNoCopy:ioData
                                                               deallocator:nil];
    self.renderProcessingCallback(buffer, format);
    return noErr;
}

static OSStatus InputCallback(void                        *inRefCon,
                              AudioUnitRenderActionFlags  *ioActionFlags,
                              const AudioTimeStamp        *inTimeStamp,
                              UInt32                       inBusNumber,
                              UInt32                       inNumberFrames,
                              AudioBufferList             *ioData)
{
    (void)ioData; // not used for input callbacks
    DefaultSystemAudioDevice *self = (__bridge DefaultSystemAudioDevice *)inRefCon;
    if (!self || !_capturing || self.capturingContext->deviceContext == NULL) {
        return noErr;
    }

    // Prepare an AudioBufferList pointing to our scratch buffer
    const size_t bytesPerFrame = sizeof(int16_t) * self.capturingFormat.numberOfChannels;
    const size_t bytesNeeded   = (size_t)inNumberFrames * bytesPerFrame;

    if (bytesNeeded > _captureScratchBytes) {
        // Should not happen if formats are consistent, but guard anyway
        return noErr;
    }

    AudioBufferList abl;
    abl.mNumberBuffers = 1;
    abl.mBuffers[0].mNumberChannels = (UInt32)self.capturingFormat.numberOfChannels;
    abl.mBuffers[0].mDataByteSize   = (UInt32)bytesNeeded;
    abl.mBuffers[0].mData           = _captureScratch;

    // Pull mic samples from RemoteIO (bus 1)
    OSStatus s = AudioUnitRender(_rioUnit, ioActionFlags, inTimeStamp, 1, inNumberFrames, &abl);
    if (s != noErr) return s;

    // Deliver to Twilio
    TVOAudioDeviceWriteCaptureData(self.capturingContext->deviceContext,
                                   (const int8_t *)abl.mBuffers[0].mData,
                                   bytesNeeded);
    self.inputProcessingCallback(ioData);
    return noErr;
}
