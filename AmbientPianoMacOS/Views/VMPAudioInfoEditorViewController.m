//
//  VMPAudioEditorView.m
//  GotchaP
//
//  Created by sumiisan on 2013/04/29.
//
//

#include <AudioToolbox/AudioToolbox.h>

#import "VMPAudioInfoEditorViewController.h"
#import "VMPSongPlayer.h"

@implementation VMPAudioInfoEditorViewController

static const CGFloat kWaveDisplayHorizontalMargin = 20;


- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	if (self) {
		self.waveScale = 1;
	}
	return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self) {
		self.waveScale = 1;
	}
	return self;
}

- (void)dealloc {
	self.audioInfo = nil;
	self.audioObject = nil;
	[super dealloc];
}

- (void)awakeFromNib {
	VMPGraph *cueRangeEditorView	= (VMPGraph*)self.cueRangeEditor.view;
	VMPGraph *regionRangeEditorView = (VMPGraph*)self.regionRangeEditor.view;
	cueRangeEditorView.		frame = self.cueRangeEditorViewPlaceHolder.frame;
	regionRangeEditorView.	frame = self.regionRangeEditorViewPlaceHolder.frame;
	cueRangeEditorView.		backgroundColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.];
	regionRangeEditorView.	backgroundColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.];
	cueRangeEditorView.		flippedYCoordinate = NO;
	regionRangeEditorView.	flippedYCoordinate = NO;
	cueRangeEditorView.		autoresizingMask = NSViewMinXMargin;
	regionRangeEditorView.	autoresizingMask = NSViewMinXMargin;
	[self.view addSubview:cueRangeEditorView];
	[self.view addSubview:regionRangeEditorView];
	[self.cueRangeEditor	setTitle:@"Cue Position" caption1:@"offset" caption2:@"duration"];
	[self.regionRangeEditor setTitle:@"Region" caption1:@"start" caption2:@"length"];

	self.waveAndMarkerView.graphDelegate = self;
	[self.waveAndMarkerView addTopOverlay];	
	[self updateFieldsAndKnobs];
}

#pragma mark -
#pragma mark ui
- (void)updateFieldsAndKnobs {
	[self.cueRangeEditor setTime1:self.audioInfo.cuePoints.locationDescriptor time2:self.audioInfo.cuePoints.lengthDescriptor];
	[self.regionRangeEditor setTime1:self.audioInfo.regionRange.locationDescriptor time2:self.audioInfo.regionRange.lengthDescriptor];
	self.volumeIndicator.floatValue = self.audioInfo.volume;
	self.volumeSlider.floatValue = self.audioInfo.volume;
	
	self.fileIdField.stringValue = (self.audioInfo.hasExplicitlySpecifiedFileId ? self.audioInfo.fileId : @"" );
	if( self.audioInfo.fileId )
		[self.fileIdField.cell setPlaceholderAttributedString:
		 [[[NSAttributedString alloc] initWithString: self.audioInfo.fileId attributes:@{
					  NSForegroundColorAttributeName:[NSColor disabledControlTextColor]
		   }] autorelease]];
}


#pragma mark -
#pragma mark accessor

- (void)setAudioInfo:(VMAudioInfo *)audioInfo {
	[_audioInfo release];
	_audioInfo = [audioInfo retain];
	[self updateFieldsAndKnobs];
	
	[self loadAudioObject:_audioInfo.fileId];
	[self plotWaveAndRanges];
}

- (void)loadAudioObject:(VMString*)fileId {
	NSString *path = [DEFAULTSONGPLAYER filePathForFileId:fileId];
	self.audioObject = [[[VMAudioObject alloc] init] autorelease];
	OSErr err = [self.audioObject load:path];
	if (err)
		NSLog(@"AudioObject load error:%d",err);
	
}

- (void)plotWaveAndRanges {
	CGFloat waveDisplayWidth = self.waveScrollView.frame.size.width - kWaveDisplayHorizontalMargin * 2;
	NSSize waveDisplaySize = NSMakeSize(waveDisplayWidth * self.waveScale,
										self.waveDisplay.frame.size.height );
	self.waveDisplay.image = [self.audioObject drawWaveImageWithSize:waveDisplaySize
														   foreColor:[NSColor colorWithCalibratedWhite:0.4 alpha:1.	]
														   backColor:[NSColor colorWithCalibratedWhite:0.95 alpha:1. ] ];
	//self.waveDisplay.frame = CGRectMakeFromOriginAndSize(self.waveDisplay.frame.origin, waveDisplaySize);
	self.waveAndMarkerView.frame = CGRectMake(self.waveAndMarkerView.x, self.waveAndMarkerView.y,
											  waveDisplaySize.width + kWaveDisplayHorizontalMargin *2, self.waveAndMarkerView.height);
	NSLog(@"wavescale:%.2f %.2f %@ | %@ / %@",self.waveScale,
		  waveDisplaySize.width,
		  NSStringFromSize(self.waveDisplay.frame.size),
		  NSStringFromSize(self.waveAndMarkerView.frame.size),
		  NSStringFromSize(self.waveAndMarkerView.bounds.size)
		  );
	self.waveAndMarkerView.needsDisplay = YES;
}

//	wave and marker view delegate
- (void)drawRect:(NSRect)dirtyRect ofView:(NSView*)view {
	CGFloat markerAreaHeight = 20;
	CGFloat x = view.frame.origin.x;
	CGFloat y = view.frame.origin.y;
	CGFloat w = view.frame.size.width;
	CGFloat h = view.frame.size.height;
	
	if ( view == self.waveAndMarkerView ) {
		//
		//	background
		//
		[[NSColor colorWithCalibratedWhite:0.6 alpha:1.] set];
		NSRectFill( NSMakeRect(x,y+h-markerAreaHeight,w,markerAreaHeight));
		[[NSColor colorWithCalibratedWhite:0.3 alpha:1.] set];
		NSRectFill( NSMakeRect(x,y,kWaveDisplayHorizontalMargin,h-markerAreaHeight));
		NSRectFill( NSMakeRect(w-kWaveDisplayHorizontalMargin,y,kWaveDisplayHorizontalMargin,h-markerAreaHeight));
	} else if ( view == self.waveAndMarkerView.topOverlay ) {
		//
		// overlay
		//
		VMFloat pixPerSec =  ( w - 2 * kWaveDisplayHorizontalMargin ) / ( _audioObject.numberOfFrames / (VMFloat)_audioObject.framesPerSecond );
		[[NSColor colorWithCalibratedRed:.6 green:.2 blue:.2 alpha:1.] setStroke];
		CGFloat offsetX = (int)(_audioInfo.offset * pixPerSec + kWaveDisplayHorizontalMargin) + 0.5;
		[NSBezierPath strokeLineFromPoint:NSMakePoint(offsetX, y) toPoint:NSMakePoint(offsetX, y+h)];
		CGFloat durationX = (int)(_audioInfo.duration * pixPerSec + offsetX ) + 0.5;
		[NSBezierPath strokeLineFromPoint:NSMakePoint(durationX, y) toPoint:NSMakePoint(durationX, y+h)];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(offsetX, (int)(y+h)-15.5) toPoint:NSMakePoint(durationX, (int)(y+h)-15.5)];
	}
}


- (void)setData:(id)data {
	self.audioInfo = data;
}

#pragma mark -
#pragma mark action
static BOOL ui_lock;

- (IBAction)openFileButtonClicked:(id)sender {
	
}

- (IBAction)zoomButtonClicked:(id)sender {
	_waveScale = ( ((NSControl*)sender).tag == 1 ) ? _waveScale * 0.5 : _waveScale * 2.;
	_waveScale = ( _waveScale < 1 ? 1 : ( _waveScale > 8 ? 8 : _waveScale ));
	[self plotWaveAndRanges];
}

- (IBAction)volumeSliderMoved:(id)sender {
	if(ui_lock)return;
	ui_lock=YES;
	self.volumeIndicator.floatValue = self.volumeSlider.floatValue;
	ui_lock=NO;
}

- (IBAction)volumeTextSet:(id)sender {
	self.volumeSlider.floatValue = self.volumeIndicator.floatValue;	
}

- (IBAction)regionSelected:(id)sender {
	
}




@end
