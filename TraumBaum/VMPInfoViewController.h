//
//  VMPInfoViewController.h
//
//  Created by sumiisan on 2013/04/03.
//
//

#import <UIKit/UIKit.h>

@protocol VMPInfoViewDelegate <NSObject>
- (void)setSkinIndex:(int)skinIndex;
@end

@interface VMPInfoViewController : UIViewController <UIScrollViewDelegate> {
	NSTimeInterval	supressToggleTrackViewUntil;
}

@property (strong, nonatomic) UIView *scrollContentView;
@property (assign)			id <VMPInfoViewDelegate> delegate;
@property (strong, nonatomic) IBOutlet UISwitch *backgroundPlaySwitch;
@property (strong, nonatomic) IBOutlet UISwitch *darkBGSwitch;
- (IBAction)buttonTouched:(id)sender;


@end
