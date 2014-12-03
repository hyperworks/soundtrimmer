@import AVFoundation;

@protocol Trimmer;

@protocol TrimmerDelegate <NSObject>

- (void)trimmerDidFinishTrimming:(id<Trimmer>)trimmer;

@end

@protocol Trimmer <NSObject>

@property (nonatomic, weak) id<TrimmerDelegate> delegate;

@property (nonatomic, copy) NSURL *inputURL;
@property (nonatomic, copy) NSURL *outputURL;

- (void)trim;

@end
