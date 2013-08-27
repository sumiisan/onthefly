//
//  TrackView.m
//  VariableMusicPlayer
//
//  Created by cboy on 12/10/26.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import "MultiPlatform.h"
#import "VMPTrackStrip.h"
#import "VMPNotification.h"
#import "VMPGraph.h"

@implementation VMPTrackStrip

//	designated initializer
- (id)initWithFrame:(VMPRect)frameRect {
    self = [super initWithFrame:frameRect];
	self.frame = frameRect;
#if VMP_OSX
	self.caption = [NSTextField labelWithText:@"" frame:VMPMakeRect(2, 2, 240, 14)];
#elif VMP_IPHONE
	self.caption = AutoRelease([[UILabel alloc] initWithFrame:VMPMakeRect(2, 2, 240, 14)]);
	self.caption.textColor = [UIColor whiteColor];
	self.caption.backgroundColor = [UIColor clearColor];
#endif
	self.caption.font = [VMPFont systemFontOfSize:11];
	[self addSubview:self.caption];
	
#if VMP_EDITOR
	VMPButton *button = [[VMPButton alloc] initWithFrame:CGRectZeroOrigin(frameRect)];
	button.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	button.transparent = YES;
	button.target = self;
	button.doubleAction = @selector(doubleClickOnTrackStrip:);
	[self addSubview:button];
#endif
	
    return self;
}

- (void)dealloc {
	VMNullify(audioFragmentId);
	VMNullify(caption);
   Dealloc( super );
}

- (void)setInfoString:(NSString *)infoString {
#if VMP_OSX
	self.caption.stringValue = infoString;
#else
	self.caption.text = infoString;
#endif
}

- (void)drawRect:(VMPRect)dirtyRect {
	[self setCanvas];
	CGFloat ox = 2;
	CGFloat oy = 1;
    CGFloat bar_left = 20 + ox;
    CGFloat y = 17 + oy;
    CGFloat bar_height = self.frame.size.height - y -4;
	CGFloat w = self.frame.size.width - bar_left - 4;
    
#ifdef VMP_IPHONE
    [self setColor_r:0.1f g:0.1f b:0.1f];
	UIRectFill(dirtyRect);
#else
    [self setColor_r:0.9f g:0.9f b:0.9f];
	NSRectFill(dirtyRect);
#endif
    
    [self setColor_r:0.8f g:0.9f b:0.5f];

    float buffered_x = loading * w;
    
    if( duration > 0 ) {
        //  total length
        [self setColor_r:0.6f g:0.65f b:0.75f];
        [self fillRect_x:bar_left + buffered_x 
                       y:y 
                       w:w-buffered_x+1
                       h:bar_height];
        
        //  buffered
        [self setColor_r:0.4f g:0.3f b:0.4f];
        [self fillRect_x:bar_left 
                       y:y 
                       w:buffered_x+1
                       h:bar_height];
        
        //  playing
		int pw = playing * w;
        if( playing > 0 ) {
            [self setColor_r:0.6f g:0.7f b:0.5f];
			if ( pw > w ) pw = w;
        } else {
            [self setColor_r:0.7f g:0.7f b:0.4f];
			if ( pw < -20 ) pw = -20;
        }
        [self fillRect_x:bar_left 
                       y:y
					   w:pw
                       h:bar_height];
        
        //  next queue
		CGFloat x = (int)(duration * w + bar_left)+0.5;
        [self setColor_r:0.3f g:0.1f b:0.1f];
        [self setLineWidth:2.];
        [self drawLine_x0:x
                       y0:y
                       x1:x
                       y1:y+bar_height];
        
        //  offset
		x = (int)(offset*w+bar_left)+0.5;
        [self drawLine_x0:x
                       y0:y
                       x1:x
                       y1:y+bar_height];

        [self setColor_r:0.4f g:0.4f b:0.4f];
        [self setLineWidth:1.];
        [self drawRect_x:((int)ox)+0.5 y:((int)oy)+16.5
					   w:(int)self.frame.size.width-5 h:((int)(oy+bar_height))];
    }
	
}

#if VMP_OSX
- (void)doubleClickOnTrackStrip:(NSEvent*)event {
	if (self.audioFragmentId)
		[VMPNotificationCenter postNotificationName:VMPNotificationFragmentDoubleClicked
											 object:self
										   userInfo:@{@"id":self.audioFragmentId}];
}
#endif
@end
