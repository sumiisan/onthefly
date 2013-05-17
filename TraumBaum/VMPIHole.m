//
//  VMPIHole.m
//  VARI
//
//  Created by sumiisan on 2013/04/03.
//
//

#import "VMPIHole.h"

@implementation VMPIHole

- (id)init {
	self = [super init];
	
	if ( self ) {
#if TARGET_OS_IPHONE
		self.backgroundColor = [VMPColor clearColor];
#endif
		CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
		CGFloat colors[] =
		{
			0.0,	0.0,	0.0,	1.0,
			0.0,	0.0,	0.0,	1.0,
			0.4,	0.4,	0.4,	1.0,
			0.95,	0.95,	0.95,	1.0,
		};
		gradient = CGGradientCreateWithColorComponents(rgb, colors, NULL, sizeof(colors)/(sizeof(colors[0])*4));
		//CGGradientRetain(gradient);
		CGColorSpaceRelease(rgb);
	}
	
	
	return self;
}


- (void)dealloc {
	CGGradientRelease(gradient);
	Dealloc( super );;
}

//- (void)drawInContext:(CGContextRef)context {
- (void)drawRect:(CGRect)dirtyRect {
	
	CGFloat radius = self.frame.size.width * 0.5;

	CGRect rect = CGRectMake(self.frame.size.width*0.5 - radius * 0.5,
							 self.frame.size.height*0.5 - radius * 0.5,
							 radius,
							 radius );
	[self setCanvas];
	CGContextSaveGState(canvas);
    CGContextAddEllipseInRect(canvas, rect);
    CGContextClip(canvas);
	
  /*  CGPoint startPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMinY(rect));
    CGPoint endPoint = CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect));
	*/
	
	CGPoint center = CGPointMake( CGRectGetMidX(rect), CGRectGetMidY(rect) );
    CGContextDrawRadialGradient(canvas, gradient, center, 0, center, radius * 0.5, 0);
	
    CGContextRestoreGState(canvas);
	
    CGContextAddEllipseInRect(canvas, rect);
  //  CGContextDrawPath(context, kCGPathStroke);
	
/*	UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(self.frame.size.width*0.5 - radius * 0.5,
																		   self.frame.size.height*0.5 - radius * 0.5,
																		   radius,
																		   radius )];
 */
/*	CGContextSetRGBFillColor(context, 0.5, 0.5, 0.5, 1.);
	CGContextAddEllipseInRect(context,CGRectMake(self.frame.size.width*0.5 - radius * 0.5,
												 self.frame.size.height*0.5 - radius * 0.5,
												 radius,
												 radius ));
	CGContextFillPath(context);
*/
		
	
	
	
}

@end
