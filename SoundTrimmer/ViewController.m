#import "ViewController.h"
#import "DSWaveformImage.h"
#import "Trimmer.h"

@interface ViewController () <TrimmerDelegate> @end

@implementation ViewController {
    NSURL *_sampleSoundURL;
    NSURL *_outputURL;
    
    AVAudioPlayer *_player;
    Trimmer *_trimmer;

    UIImage *_before;
    UIImage *_after;
}

- (NSURL *)sampleSoundURL {
    if (_sampleSoundURL) { return _sampleSoundURL; }

    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *samplePath = [mainBundle pathForResource:@"sample" ofType:@"aac"];
    return _sampleSoundURL = [NSURL fileURLWithPath:samplePath];
}

- (NSURL *)outputURL {
    if (_outputURL) { return _outputURL; }

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    path = [path stringByAppendingPathComponent:@"output.aac"];
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
        typeof(self) s = self_;
        if (!s) return;

        Trimmer *trimmer = [[Trimmer alloc] init];
        [trimmer setDelegate:s];
        [trimmer setInputURL:[s sampleSoundURL]];
        [trimmer setOutputURL:[s outputURL]];
        [trimmer trim];

        s->_trimmer = trimmer;
    });
}


- (void)didTapPlayBefore {
    if (_player) [_player stop];

    _player = [[AVAudioPlayer alloc] initWithContentsOfURL:[self sampleSoundURL] error:nil];
    [_player play];
}

- (void)didTapPlayAfter {
    if (_player) [_player stop];

    _player = [[AVAudioPlayer alloc] initWithContentsOfURL:[self outputURL] error:nil];
    [_player play];
}


- (void)trimmerDidFinishTrimming:(Trimmer *)trimmer {
    NSLog(@"done trimming.");
    _after = [DSWaveformImage waveformForAssetAtURL:[self outputURL]
                                              color:[UIColor whiteColor]
                                               size:CGSizeMake(1024, 256)
                                              scale:1.0
                                              style:DSWaveformStyleStripes];
    [_afterImageView setImage:_after];
}

@end
