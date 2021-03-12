//
//  VMPColorAnimation.h
//  OnTheFly
//
//  Created by sumiisan on 2013/11/22.
//
//

#import <Cocoa/Cocoa.h>
#import "MultiPlatform.h"
@interface VMPColorAnimation : NSAnimation

@property (nonatomic, retain)	id  target;
@property (nonatomic)			SEL method;
@property (nonatomic, retain)	NSColor *color1;
@property (nonatomic, retain)	NSColor *color2;

@end
