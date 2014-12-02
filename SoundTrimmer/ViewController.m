#import "ViewController.h"
#import "DSWaveformImage.h"
#import "Trimmer.h"

@implementation ViewController {
    AVAudioPlayer *_player;
    Trimmer *_trimmer;

    UIImage *_before;
    UIImage *_after;
}

- (NSURL *)sampleSoundURL {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *samplePath = [mainBundle pathForResource:@"sample" ofType:@"aac"];
    return [NSURL fileURLWithPath:samplePath];
}

- (NSURL *)outputURL {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    path = [path stringByAppendingPathComponent:@"output.aac"];
    return [NSURL fileURLWithPath:path];
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


@end
