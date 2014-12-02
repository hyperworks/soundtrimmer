#import "Trimmer.h"

#define MINMAX(x, min, max) MIN(max, MAX(min, x))
#define DECIBEL(x) (20.0 * log10(ABS(x)/32767.0))
#define NOISE_FLOOR (-50.0)

@implementation Trimmer {
    AVAssetWriter *_writer;
    AVAssetWriterInput *_input;
}

- (void)trim {
    assert(_inputURL && _outputURL);

    AVURLAsset *asset = [AVURLAsset assetWithURL:_inputURL];
    AVAssetTrack *track = [[asset tracks] objectAtIndex:0];

    // Extract sample rate and channel count from track metadata.
    UInt32 sampleRate = 0, channelCount = 0;
    NSArray *descriptions = [track formatDescriptions];
    const AudioStreamBasicDescription *description = nil;
    for (unsigned int i = 0; i < [descriptions count]; i++) {
        CMAudioFormatDescriptionRef item = nil;
        item = (CMAudioFormatDescriptionRef)CFBridgingRetain([descriptions objectAtIndex:i]);

        description = CMAudioFormatDescriptionGetStreamBasicDescription(item);
        if (description) {
            sampleRate = description->mSampleRate;
            channelCount = description->mChannelsPerFrame;
        }
    }

    // readout entire audio data as NSData
    NSDictionary *outputSettings =
    @{ AVFormatIDKey: @(kAudioFormatLinearPCM),
       AVSampleRateKey: @(sampleRate),
       AVNumberOfChannelsKey: @(channelCount),
       AVLinearPCMBitDepthKey: @(16),
       AVLinearPCMIsBigEndianKey: @(NO),
       AVLinearPCMIsFloatKey: @(NO),
       AVLinearPCMIsNonInterleaved: @(NO) };

    AVAssetReaderTrackOutput *trackOutput = [AVAssetReaderTrackOutput alloc];
    trackOutput = [trackOutput initWithTrack:track outputSettings:outputSettings];

    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:asset error:nil];
    [reader addOutput:trackOutput];
    [reader startReading];

    NSMutableData *audioData = [[NSMutableData alloc] initWithCapacity:1*1024*1024];
    while (reader.status == AVAssetReaderStatusReading) {
        AVAssetReaderTrackOutput *trackOutput = (AVAssetReaderTrackOutput *)[reader.outputs objectAtIndex:0];
        CMSampleBufferRef sampleBufferRef = [trackOutput copyNextSampleBuffer];

        if (sampleBufferRef) {
            CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
            size_t length = CMBlockBufferGetDataLength(blockBufferRef);

            NSMutableData *blockData = [NSMutableData dataWithLength:length];
            CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, blockData.mutableBytes);
            [audioData appendData:blockData];
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
        }
    }

    assert(reader.status == AVAssetReaderStatusCompleted);
    // TODO: Handle errorneous reader.status

    // find non-silence brackets
    SInt16 *voiceStartPoint, *voiceStopPoint;
    BOOL voiceBegan = false;

    SInt16 *inSamples = (SInt16 *)[audioData mutableBytes];
    voiceStartPoint = voiceStopPoint = inSamples;

    for (int i = 0; i < [audioData length]; i++) {
        Float32 amplitude = (Float32)*inSamples;
        amplitude = DECIBEL(amplitude);
        amplitude = MINMAX(amplitude, NOISE_FLOOR, 0);

        if (!voiceBegan) {
            if (amplitude == NOISE_FLOOR) {
                voiceStartPoint = inSamples;
            } else {
                voiceBegan = true;
            }
        } else {
            if (amplitude != NOISE_FLOOR) {
                voiceStopPoint = inSamples;
            }
        }
    }

    // TODO: Pad with silence so there's a small aesthetical pause between sounds.

    // copy out non-silenced parts
    UInt32 voiceLength = voiceStopPoint - voiceStartPoint + 1;
    CMBlockBufferRef outputBuffer = nil;
    CMSampleBufferRef sampleBuffer = nil;
    OSStatus status = 0;

    // TODO: Properly align to sample boundary?
    status = CMBlockBufferCreateWithMemoryBlock(NULL, voiceStartPoint, voiceLength, NULL, NULL, 0, voiceLength, 0, &outputBuffer);
    assert(status == 0);
    status = CMSampleBufferCreate(NULL, outputBuffer, YES, NULL, NULL, NULL, 0, 0, NULL, 0, NULL, &sampleBuffer);
    assert(status == 0);

    outputSettings =
    @{ AVFormatIDKey: @(kAudioFormatMPEG4AAC),
       AVSampleRateKey: @(sampleRate),
       AVNumberOfChannelsKey: @(channelCount),
//       AVLinearPCMBitDepthKey: @(16),
//       AVLinearPCMIsBigEndianKey: @(NO),
//       AVLinearPCMIsFloatKey: @(NO),
//       AVLinearPCMIsNonInterleaved: @(NO),
//       AVLinearPCMBitDepthKey: @(6),
       };

    // public.mpeg-4, public.3gpp, com.apple.coreaudio-format, com.apple.quicktime-movie,
    // com.apple.m4a-audio, com.apple.m4v-video, org.3gpp.adaptive-multi-rate-audio,
    // public.aiff-audio, com.microsoft.waveform-audio, public.aifc-audio
    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:_outputURL
                                                     fileType:@"com.apple.m4a-audio"//"com.microsoft.waveform-audio"
                                                        error:nil];
    
    AVAssetWriterInput *input = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:outputSettings];
    
    
//     = [[AVAssetWriterInput alloc] assetWriterInputWithMediaType:AVMediaTypeAudio
 //                                                                  outputSettings:outputSettings];
    
//    [writer addInput:input];
    input.expectsMediaDataInRealTime = YES;
    if ([writer canAddInput:input])
        [writer addInput:input];
    
    NSLog(@"----");
    NSLog(writer.error);
    NSLog(@"----");
//    NSLog(input.error);

    
    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    
    Boolean x = [input isReadyForMoreMediaData]; // <- fails

    [input appendSampleBuffer:sampleBuffer];
    CFRelease(sampleBuffer);
    CFRelease(outputBuffer);

    [input markAsFinished];

    _writer = writer;
    _input = input;
}

@end
