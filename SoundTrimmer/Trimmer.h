@import AVFoundation;

@class Trimmer;

@protocol TrimmerDelegate <NSObject>

- (void)trimmerDidFinishTrimming:(Trimmer *)trimmer;

@end

@interface Trimmer: NSObject

@property (nonatomic, weak) id<TrimmerDelegate> delegate;

@property (nonatomic, copy) NSURL *inputURL;
@property (nonatomic, copy) NSURL *outputURL;

- (void)trim;

@end