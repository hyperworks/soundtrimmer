@import AVFoundation;

@interface Trimmer: NSObject

@property (nonatomic, copy) NSURL *inputURL;
@property (nonatomic, copy) NSURL *outputURL;

- (void)trim;

@end