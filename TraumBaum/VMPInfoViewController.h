//
//  VMPFrontView.h
//  VARI
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
@end
