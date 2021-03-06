#import "ViewController.h"
#import "DSWaveformImage.h"
#import "AVTrimmer.h"

@interface ViewController () <TrimmerDelegate> @end

@implementation ViewController {
    NSURL *_sampleSoundURL;
    NSURL *_outputURL;
    
    AVAudioPlayer *_player;
    id<Trimmer> _trimmer;

    UIImage *_before;
    UIImage *_after;
}

- (id<Trimmer>)trimmer {
    if (_trimmer) return _trimmer;
    
    id<Trimmer> t = [[AVTrimmer alloc] init];
    [t setDelegate:self];
    [t setInputURL:[self sampleSoundURL]];
    [t setOutputURL:[self outputURL]];
    return _trimmer = t;
}

- (NSURL *)sampleSoundURL {
    if (_sampleSoundURL) { return _sampleSoundURL; }

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *samplePath = [mainBundle pathForResource:@"sample" ofType:@"aac"];
    return _sampleSoundURL = [NSURL fileURLWithPath:samplePath];
}

- (NSURL *)outputURL {
    if (_outputURL) { return _outputURL; }

    NSString *filename = [[NSUUID UUID] UUIDString];
    filename = [filename stringByAppendingString:@".m4a"];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    path = [path stringByAppendingPathComponent:filename];
    return _outputURL = [NSURL fileURLWithPath:path];
}

- (void)dealloc {
    if (_player) {
        [_player stop];
        _player = nil;
    }

    _trimmer = nil;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    _before = [DSWaveformImage waveformForAssetAtURL:[self sampleSoundURL]
                                               color:[UIColor whiteColor]
                                                size:CGSizeMake(1024, 256)
                                               scale:1.0
                                               style:DSWaveformStyleStripes];
    _after = nil;
    [_beforeImageView setImage:_before];
    [_afterImageView setImage:_after];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    __weak typeof(self) self_ = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self_ trimmer] trim];
    });
}


- (void)didTapPlayBefore { [self playURL:[self sampleSoundURL]]; }
- (void)didTapPlayAfter { [self playURL:[self outputURL]]; }

- (void)playURL:(NSURL *)soundURL {
    if (_player) {
        [_player stop];
        _player = nil;
    }

    NSError *err = nil;
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundURL error:&err];
    if (err != nil) {
        NSLog(@"%@", err);
        _player = nil;

    } else {
        [player play];
        _player = player;

    }
}


- (void)trimmerDidFinishTrimming:(id<Trimmer>)trimmer {
    NSLog(@"done trimming.");
    _after = [DSWaveformImage waveformForAssetAtURL:[self outputURL]
                                              color:[UIColor whiteColor]
                                               size:CGSizeMake(1024, 256)
                                              scale:1.0
                                              style:DSWaveformStyleStripes];
    [_afterImageView setImage:_after];
}

@end
