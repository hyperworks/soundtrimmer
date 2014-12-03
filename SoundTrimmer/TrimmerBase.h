@import Foundation;
#import "Trimmer.h"

@interface TrimmerBase : NSObject <Trimmer>

@end

@interface TrimmerBase (Private)

- (void)didFinishTrimming;

@end
