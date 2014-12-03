#import "Trimmer.h"

#define IS_NOISE(amplitude) (amplitude > 10.0)

@implementation Trimmer {
    AVAssetWriter *_writer;
}

- (void)trim {
    assert(_inputURL && _outputURL);
    NSLog(@"input url: %@", _inputURL);
    NSLog(@"output url: %@", _outputURL);

    AVURLAsset *asset = [AVURLAsset assetWithURL:_inputURL];
    AVAssetTrack *track = [[asset tracks] objectAtIndex:0];

    // Extract sample rate and channel count from track metadata.
    NSArray *descriptions = [track formatDescriptions];
    const AudioStreamBasicDescription *description = nil;
    for (unsigned int i = 0; i < [descriptions count]; i++) {
        CMAudioFormatDescriptionRef item = nil;
        item = (CMAudioFormatDescriptionRef)CFBridgingRetain([descriptions objectAtIndex:i]);

        description = CMAudioFormatDescriptionGetStreamBasicDescription(item);
    }
    
    assert(description);

    // readout entire audio data as NSData
    Float64 sampleRate = description->mSampleRate;
    UInt32 channelCount = description->mChannelsPerFrame;
    
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
    assert([audioData length] > 0);

    // find non-silence brackets
    SInt16 *voiceStartPoint, *voiceStopPoint;
    BOOL voiceBegan = false;

    SInt16 *inSamples = (SInt16 *)[audioData mutableBytes];
    voiceStartPoint = voiceStopPoint = inSamples;

    UInt32 max = (UInt32)([audioData length] / channelCount);
    for (int i = 0; i < max; i += channelCount) {
        SInt16 *frameStart = inSamples;
        
        SInt16 sum = 0;
        for (int j = 0; j < channelCount; j++) {
            sum += *inSamples++;
        }
        
        if (!voiceBegan) {
            if (IS_NOISE(sum)) {
                voiceStartPoint = frameStart;
            } else {
                voiceBegan = true;
            }
        } else {
            if (IS_NOISE(sum)) {
                voiceStopPoint = frameStart;
            }
        }
    }

    // TODO: Pad with silence so there's a small aesthetical pause between sounds.

    // copy out non-silenced parts
    UInt32 voiceLength = (UInt32)(voiceStopPoint - voiceStartPoint + 1);
    voiceLength = (UInt32)[audioData length];
    CMBlockBufferRef outputBuffer = nil;
    CMSampleBufferRef sampleBuffer = nil;
    OSStatus status = 0;
    
    UInt32 samplesCount = voiceLength >> 1; // since we're using 16bit samples.
    size_t sampleSize = 2;

    // TODO: Properly align to sample boundary?
    status = CMBlockBufferCreateEmpty(NULL, 0, 0, &outputBuffer);
    assert(status == 0);
    status = CMBlockBufferAppendMemoryBlock(outputBuffer, voiceStartPoint, voiceLength, kCFAllocatorNull, NULL, 0, voiceLength, 0);
    assert(status == 0);
    status = CMSampleBufferCreate(kCFAllocatorDefault, outputBuffer, true, NULL, NULL, NULL, samplesCount, 0, NULL, 1, &sampleSize, &sampleBuffer);
    assert(status == 0);
    
    outputSettings =
    @{ AVFormatIDKey: @(kAudioFormatLinearPCM),
       AVSampleRateKey: @(sampleRate),
       AVNumberOfChannelsKey: @(channelCount),
       AVLinearPCMBitDepthKey: @(16),
       AVLinearPCMIsBigEndianKey: @(NO),
       AVLinearPCMIsFloatKey: @(NO),
       AVLinearPCMIsNonInterleaved: @(NO) };
    

    AVAssetWriter *writer = [AVAssetWriter assetWriterWithURL:_outputURL
                                                     fileType:@"com.microsoft.waveform-audio"
                                                        error:nil];
    AVAssetWriterInput *input = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
                                                                   outputSettings:outputSettings];
    [input setExpectsMediaDataInRealTime:NO];
    assert([writer canAddInput:input]);
    [writer addInput:input];

    _writer = writer;

    [writer startWriting];
    [writer startSessionAtSourceTime:kCMTimeZero];
    
    BOOL result = [input appendSampleBuffer:sampleBuffer];
    assert(result);
    
    [input markAsFinished];
    [writer finishWritingWithCompletionHandler:^{
        assert([writer status] == AVAssetWriterStatusCompleted);
        
        NSFileManager *mgr = [NSFileManager defaultManager];
        NSDictionary *attributes = [mgr attributesOfItemAtPath:[_outputURL path] error:nil];
        NSLog(@"output size: %@", [attributes objectForKey:NSFileSize]);
        
        [self didFinishTrimming];
    }];
}

- (void)didFinishTrimming {
    if ([_delegate respondsToSelector:@selector(trimmerDidFinishTrimming:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate trimmerDidFinishTrimming:self];
        });
    }
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object != _writer) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }

    if ([keyPath isEqualToString:@"status"]) {
        if ([_writer status] == AVAssetWriterStatusCompleted) {
            [_writer removeObserver:self forKeyPath:keyPath];
            [self didFinishTrimming];
        }
        // TODO: Handle writer errors.
    }
}

@end
