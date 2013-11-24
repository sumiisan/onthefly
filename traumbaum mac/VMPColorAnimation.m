//
//  VMPColorAnimation.m
//  OnTheFly
//
//  Created by sumiisan on 2013/11/22.
//
//

#import "VMPColorAnimation.h"

@implementation VMPColorAnimation

@synthesize target = target_;
@synthesize method = method_;
@synthesize color1 = color1_;
@synthesize color2 = color2_;

- (void) setCurrentProgress:(NSAnimationProgress) d
{
    [super setCurrentProgress:d];
    NSColor *currentColor = [color1_ blendedColorWithFraction:d ofColor:color2_];
    [target_ performSelector:method_ withObject:currentColor];
}

@end
