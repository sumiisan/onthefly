//
//  VMPInfoViewController.h
//
//  Created by sumiisan on 2013/04/03.
//
//

#import <UIKit/UIKit.h>

@interface VMPInfoViewController : UIViewController <UIAlertViewDelegate,NSURLConnectionDataDelegate,UIWebViewDelegate> {
	NSTimeInterval	supressToggleTrackViewUntil;
}

@property (strong, nonatomic) IBOutlet UISwitch *backgroundPlaySwitch;
@property (strong, nonatomic) IBOutlet UILabel *statisticsLabel;

- (IBAction)buttonTouched:(id)sender;
- (void)showView;
- (void)closeView;

@end
