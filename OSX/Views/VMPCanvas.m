//
//  apCanvas.m
//  OnTheFly
//
//  Created by cboy on 10/04/18.
//  Copyright 2010 sumiisan (sumiisan.com). All rights reserved.
//

#import "VMPCanvas.h"
#include "MultiPlatform.h"

@implementation VMPCanvas
#if VMP_OSX
@synthesize tag = tag_;
@synthesize backgroundColor = backgroundColor_;
#endif

- (id)initWithFrame:(VMPRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // Initialization code
    }
    return self;
}

- (void)dealloc {
	VMNullify(backgroundColor);
	Dealloc( super );;	
}

#if VMP_OSX
- (NSInteger)tag {
	return tag_;
}

- (void)setTag:(NSInteger)tag {
	tag_ = tag;
}
#endif


- (void)drawRect:(VMPRect)rect {
	[super drawRect:rect];
#if VMP_OSX
	if ( self.backgroundColor ) {
		[self.backgroundColor setFill];
		NSRectFill(rect);
	}
#else
//		UIRectFill(rect);	//	let UIView do this.
#endif
}

#if VMP_OSX
- (BOOL)isFlipped {     //  matches NSView's coordinates to UIView
    return YES;
}
#endif


-(void)setCanvas {
#if VMP_IPHONE
	canvas = UIGraphicsGetCurrentContext();	
#elif VMP_OSX
    canvas = [[NSGraphicsContext currentContext] graphicsPort];
#endif
}

- (void)setColor_r:(float)r g:(float)g b:(float)b {
	CGContextSetRGBFillColor(canvas,r,g,b,1.0f);
	CGContextSetRGBStrokeColor(canvas,r,g,b,1.0f);
}

- (void)setLineWidth:(float)w {
	if (w<0.0f) w=0.0f;
	CGContextSetLineWidth(canvas,w);
}

- (void)drawLine_x0:(float)x0 y0:(float)y0 x1:(float)x1 y1:(float)y1 {
	CGContextSetLineCap(canvas,kCGLineCapButt);
	CGContextMoveToPoint(canvas,x0,y0);
	CGContextAddLineToPoint(canvas,x1,y1);
	CGContextStrokePath(canvas);
}

- (void)drawRect_x:(float)x y:(float)y w:(float)w h:(float)h {    
	CGContextSetLineCap(canvas,kCGLineCapButt);
	CGContextMoveToPoint(canvas,x,y);
	CGContextAddLineToPoint(canvas,x+w,y);
	CGContextAddLineToPoint(canvas,x+w,y+h);
	CGContextAddLineToPoint(canvas,x,y+h);
	CGContextAddLineToPoint(canvas,x,y);
	CGContextStrokePath(canvas);
}

- (void)fillRect_x:(float)x y:(float)y w:(float)w h:(float)h {    
	CGContextFillRect(canvas,CGRectMake(x,y,w,h));
}

- (void)drawCircle_x:(float)x y:(float)y w:(float)w h:(float)h {    
	CGContextAddEllipseInRect(canvas,CGRectMake(x,y,w,h));
	CGContextStrokePath(canvas);
}

- (void)fillCircle_x:(float)x y:(float)y w:(float)w h:(float)h {    
	CGContextFillEllipseInRect(canvas,CGRectMake(x,y,w,h));
}


@end
