//
//  VMPProgressView.m
//  OnTheFly
//
//  Created by sumiisan on 2014/02/16.
//
//

#import "VMPProgressView.h"
#import "VMPMultiLanguage.h"

@implementation VMPProgressView
@synthesize progress=progress_;
	
- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(20,15,frame.size.width-40,15)];
		lb.text = [VMPMultiLanguage downloadingMessage];
		lb.textColor = [UIColor blackColor];
		lb.backgroundColor = [UIColor clearColor];
		lb.textAlignment = NSTextAlignmentCenter;
		lb.font = [UIFont systemFontOfSize:11];
		[self addSubview:lb];
		UIProgressView *pv = [[UIProgressView alloc] initWithFrame:CGRectMake(20, 55, frame.size.width-40, 10)];
		pv.tag = 900;
		[self addSubview:pv];
		[pv release];
		[lb release];
 
		CGRect screenRect = [UIScreen mainScreen].bounds;
		self.frame = CGRectMake((screenRect.size.width - frame.size.width) * 0.5,
								(screenRect.size.height - frame.size.height) * 0.5,
								frame.size.width,
								frame.size.height);
		
		self.backgroundColor = [UIColor colorWithRed:.9 green:.9 blue:.9 alpha:0.7];
    }
    return self;
}
	
- (void)setProgress:(double)progress {
	progress_ = progress;
	UIProgressView *pv = (UIProgressView*)[self viewWithTag:900];
	pv.progress = progress;
}

- (double)progress {
	return progress_;
}

@end
