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
}

@property (strong, nonatomic) UIView *scrollContentView;
@property (weak)			  id <VMPInfoViewDelegate> delegate;
@end
