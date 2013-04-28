//
//  VMPScrollViewClipper.m
//  GotchaP
//
//  Created by sumiisan on 2013/04/13.
//
//

#import "VMPScrollViewClipper.h"

@implementation VMPScrollViewClipper

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
		
	
    }
    return self;
}

-(UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    UIView* child = nil;
    if ((child = [super hitTest:point withEvent:event]) == self)
    	return self.scrollView;
    return child;
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
