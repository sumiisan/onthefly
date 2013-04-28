//
//  VMPIHole.h
//  VARI
//
//  Created by sumiisan on 2013/04/03.
//
//
#import "VMPCanvas.h"
//#import <QuartzCore/QuartzCore.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
@interface VMPIHole : VMPCanvas {	//	CALayer
	CGGradientRef	gradient;
}
@end
