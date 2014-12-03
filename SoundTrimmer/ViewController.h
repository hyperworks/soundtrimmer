@import UIKit;
#import "Trimmer.h"

@interface ViewController: UIViewController

@property (nonatomic, readonly) id<Trimmer> trimmer;

@property (nonatomic) IBOutlet UIImageView *beforeImageView;
@property (nonatomic) IBOutlet UIImageView *afterImageView;

- (IBAction)didTapPlayBefore;
- (IBAction)didTapPlayAfter;

@end