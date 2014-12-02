@import UIKit;

@interface ViewController: UIViewController

@property (nonatomic) IBOutlet UIImageView *beforeImageView;
@property (nonatomic) IBOutlet UIImageView *afterImageView;

- (IBAction)didTapPlayBefore;
- (IBAction)didTapPlayAfter;

@end