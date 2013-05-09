//
//  apCanvas.h
//  OnTheFly
//
//  Created by cboy on 10/04/18.
//  Copyright 2010 sumiisan (aframasda.com). All rights reserved.
//

#import "MultiPlatform.h"

//
//  iOS
//
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif
@interface VMPCanvas : VMPView {
	CGContextRef	canvas;
	NSInteger		tag_;
}



- (void)setCanvas;
- (void)setColor_r:(float)r g:(float)g b:(float)b;
- (void)setLineWidth:(float)w;
- (void)drawLine_x0:(float)x0 y0:(float)y0 x1:(float)x1 y1:(float)y1;
- (void)drawRect_x:(float)x y:(float)y w:(float)w h:(float)h;
- (void)fillRect_x:(float)x y:(float)y w:(float)w h:(float)h;
- (void)drawCircle_x:(float)x y:(float)y w:(float)w h:(float)h;
- (void)fillCircle_x:(float)x y:(float)y w:(float)w h:(float)h;

@property (nonatomic, assign) NSInteger tag;		//	override
@property (nonatomic, retain) NSColor	*backgroundColor;

@end
