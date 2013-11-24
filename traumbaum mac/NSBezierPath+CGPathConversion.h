//
//  NSBezierPath+CGPathConversion.h
//  OnTheFly
//
//  Created by sumiisan on 2013/11/21.
//
//

#import <Cocoa/Cocoa.h>

@interface NSBezierPath (CGPathConversion)
- (CGPathRef)quartzPath;
@end
