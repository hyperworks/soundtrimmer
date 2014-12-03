#import "TrimmerBase.h"

@implementation TrimmerBase {
    __weak id<TrimmerDelegate> _delegate;
    NSURL *_inputURL, *_outputURL;
}

- (instancetype)init {
    if (self = [super init]) {
        _delegate = nil;
        _inputURL = _outputURL = nil;
    }
    return self;
}


- (id<TrimmerDelegate>)delegate { return _delegate; }

- (void)setDelegate:(id<TrimmerDelegate>)delegate {
    [self willChangeValueForKey:@"delegate"];
    _delegate = delegate;
    [self didChangeValueForKey:@"delegate"];
}

- (NSURL *)inputURL { return _inputURL; }

- (void)setInputURL:(NSURL *)inputURL {
    [self willChangeValueForKey:@"inputURL"];
    _inputURL = inputURL;
    [self didChangeValueForKey:@"inputURL"];
}

- (NSURL *)outputURL { return _outputURL; }

- (void)setOutputURL:(NSURL *)outputURL {
    [self willChangeValueForKey:@"outputURL"];
    _outputURL = outputURL;
    [self didChangeValueForKey:@"outputURL"];
}

- (void)trim {
    assert(false);
}

@end

@implementation TrimmerBase (Private)

- (void)didFinishTrimming {
    if ([_delegate respondsToSelector:@selector(trimmerDidFinishTrimming:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_delegate trimmerDidFinishTrimming:self];
        });
    }
}

@end
