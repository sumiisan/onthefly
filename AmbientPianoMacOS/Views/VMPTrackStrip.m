//
//  TrackView.m
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/26.
//  Copyright 2012 sumiisan@gmail.com. All rights reserved.
//

#import "VMPTrackStrip.h"
#import "MultiPlatform.h"

@implementation VMPTrackStrip

- (id)init
{
    self = [super init];
    if (self) {
        infoString = nil;
        // Initialization code here.
    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
}


#if ! TARGET_OS_IPHONE
- (BOOL)isFlipped {     //  matches NSView's coordinates to UIView
    return YES;
}
#endif


- (void)drawRect:(VMPRect)rect {
	[self setCanvas];
    CGFloat bar_left = 20;
    CGFloat y = 20;
    CGFloat bar_height = self.frame.size.height - y;
	CGFloat w = self.frame.size.width - bar_left;
    
#ifdef VMP_MOBILE
    [self setColor_r:0.1f g:0.1f b:0.1f];
    [self fillRect_x:0 y:0 w:self.frame.size.width h:self.frame.size.height];
#endif
    
    [self setColor_r:0.8f g:0.7f b:0.5f];
        
#if TARGET_OS_IPHONE
	[infoString
     drawAtPoint:CGPointMake( 0, 3 ) 
     withFont:[VMPFont systemFontOfSize:14]];
#elif TARGET_OS_MAC
    [infoString
     drawAtPoint:NSPointFromCGPoint( CGPointMake( 0, 3 ) ) 
     withAttributes:NULL ];
#endif
    float buffered_x = loading * w;
    
    if( duration > 0 ) {
        //  total length
        [self setColor_r:0.6f g:0.65f b:0.75f];
        [self fillRect_x:bar_left + buffered_x 
                       y:y 
                       w:w-buffered_x 
                       h:bar_height];
        
        //  buffered
        [self setColor_r:0.4f g:0.5f b:0.4f];
        [self fillRect_x:bar_left 
                       y:y 
                       w:buffered_x 
                       h:bar_height];
        
        //  playing
        if( playing > 0 ) {
            [self setColor_r:0.6f g:0.7f b:0.5f];
        } else {
            [self setColor_r:0.7f g:0.7f b:0.4f];
        }
        [self fillRect_x:bar_left 
                       y:y w:playing * w 
                       h:bar_height];
        
        //  next queue 
        [self setColor_r:0.3f g:0.1f b:0.1f];
        [self setLineWidth:2.];
        [self drawLine_x0:duration * w +bar_left 
                       y0:y
                       x1:duration * w +bar_left 
                       y1:y+bar_height];
        
        //  offset
        [self drawLine_x0:offset * w +bar_left 
                       y0:y
                       x1:offset * w +bar_left 
                       y1:y+bar_height];

        [self setColor_r:0.0f g:0.0f b:0.0f];
        [self setLineWidth:1.];
        [self drawRect_x:0 y:20 w:self.frame.size.width h:bar_height];
        

    }
	
}

@end
