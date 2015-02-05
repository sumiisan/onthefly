//
//  VMPFragmentCell.m
//  OnTheFly
//
//  Created by sumiisan on 2013/05/18.
//
//

#import "VMPFragmentCell.h"
#import "VMPNotification.h"
#import "MultiPlatform.h"
#import "VMPMacros.h"
#import "VMPSongPlayer.h"




#pragma mark -
#pragma mark *** Fragment Graph Base ***
#pragma mark -
/*---------------------------------------------------------------------------------
 *
 *
 *	Fragment Graph Base
 *
 *
 *---------------------------------------------------------------------------------*/

@interface VMPFragmentGraphBase ()
@property (nonatomic, VMStrong) VMPButton *button;
@end

@implementation VMPFragmentGraphBase
@synthesize		fragment=_fragment;

//	static vars
static NSDictionary *headerTextAttributes_static_	= nil;
static NSDictionary *idTextAttributes_static_		= nil;
static NSDictionary *positionTextAttributes_static_ = nil;
static NSShadow		*defaultShadow_static_			= nil;
static NSShadow		*smallShadow_static_			= nil;


- (id)initWithFrame:(NSRect)frameRect {
	
	self = [super initWithFrame:frameRect];
	
	self.wantsLayer = kUseCoreAnimationLayerForEditor;	//TEST
	//
	//	init static vars
	//
	if ( ! idTextAttributes_static_ ) {
		//
		// setup string attributes.
		//
		NSMutableParagraphStyle *ps = ARInstance(NSMutableParagraphStyle);
		ps.lineBreakMode = NSLineBreakByCharWrapping;
		idTextAttributes_static_ = @{	NSForegroundColorAttributeName:[NSColor blackColor],
								NSFontAttributeName:[NSFont systemFontOfSize:10],
								NSParagraphStyleAttributeName:AutoRelease([ps copy])};
		Retain(idTextAttributes_static_);
		
		ps.lineBreakMode = NSLineBreakByTruncatingTail;
		headerTextAttributes_static_ = @{
								   NSForegroundColorAttributeName:[NSColor whiteColor],
		   NSFontAttributeName:[NSFont systemFontOfSize:10],
		   NSParagraphStyleAttributeName:AutoRelease([ps copy])};
		Retain(headerTextAttributes_static_);

		ps.lineBreakMode = NSLineBreakByClipping;
		ps.alignment = NSCenterTextAlignment;
		positionTextAttributes_static_ = @{ NSForegroundColorAttributeName:[NSColor whiteColor],
									  NSFontAttributeName:[NSFont systemFontOfSize:9],
									  NSParagraphStyleAttributeName:ps };
		Retain(positionTextAttributes_static_);

		//
		//	setup shadow
		//
		defaultShadow_static_ = [[NSShadow alloc] init];
		[defaultShadow_static_ setShadowOffset:NSMakeSize(vmpShadowOffset, -vmpShadowOffset)];
		[defaultShadow_static_ setShadowBlurRadius:vmpShadowBlurRadius];
		[defaultShadow_static_ setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.5]];
		
		smallShadow_static_   = [[NSShadow alloc] init];
		[smallShadow_static_ setShadowOffset:NSMakeSize(1,-1)];
		[smallShadow_static_ setShadowBlurRadius:2.];
		[smallShadow_static_ setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.3]];
	}

	if (self) {
		[self initCell];
		self.frame = frameRect;
	}
	return self;
}

- (void)dealloc {
	[VMPNotificationCenter removeObserver:self];
	VMNullify( fragment );
    VMNullify( button );
	VMNullify( backgroundGradient );
	Dealloc( super );
}


- (id)init {
	assert(0);	//	use initWithFrame
	return nil;
}

- (void)initCell {
	
	//	default bg gradient
	self.backgroundGradient = AutoRelease([[NSGradient alloc] initWithStartingColor:VMPColorBy(.9, .9, .9, 1.)
																		endingColor:VMPColorBy(.7, .7, .7, 1.)]);

	VMPButton *b = AutoRelease( [[VMPButton alloc] initWithFrame:self.contentRect] );
	b.target=self;
	b.action=@selector(click:);
	b.doubleAction=@selector(doubleClick:);
	[b setTransparent:YES];
	[self addSubview:b];
	self.button = b;
	self.toolTip = self.fragment.id;
}

#pragma mark accessor

- (void)setFrame:(NSRect)frameRect {
	self.contentRect = CGRectOffset( CGRectZeroOrigin(frameRect), vmpShadowBlurRadius, vmpShadowBlurRadius );
	frameRect = CGRectMake(frameRect.origin.x - vmpShadowBlurRadius,
						   frameRect.origin.y - vmpShadowBlurRadius,
						   frameRect.size.width + vmpShadowOffset + vmpShadowBlurRadius *2,
						   frameRect.size.height + vmpShadowOffset + vmpShadowBlurRadius *2 );
	[super setFrame:frameRect];
	[self.button setFrame:self.contentRect];
}

- (void)setPlaying:(BOOL)playing {
	self.needsDisplay = ( _playing != playing );
	_playing = playing;
}

- (void)setSelected:(BOOL)selected {
	self.needsDisplay |= ( _selected != selected );
	_selected = selected;
}

- (void)setData:(id)data {
	self.fragment = data;
}

- (VMFragment*)fragment {
	return _fragment;
}

- (void)setFragment:(VMFragment *)frag {
	Release( _fragment );
	_fragment = Retain( frag );
	
	[VMPNotificationCenter removeObserver:self];
	//	add observer
	if ( _fragment.type == vmObjectType_sequence || _fragment.type == vmObjectType_audioFragment ) {
		[VMPNotificationCenter addObserver:self
								  selector:@selector(audioFragmentFired:)
									  name:VMPNotificationAudioFragmentFired
									object:nil];
		[VMPNotificationCenter addObserver:self
								  selector:@selector(audioFragmentFired:)
									  name:VMPNotificationStartChaseSequence
									object:nil];
		self.playing = [self.fragment containsId:DEFAULTSONGPLAYER.lastFiredFragment.id];
	}
}

- (void)click:(id)sender {
	self.selected = !self.selected;
	if ( self.fragment.id )
		[VMPNotificationCenter postNotificationName:VMPNotificationFragmentSelected
											 object:self
										   userInfo:@{@"id":self.fragment.id} ];
	self.needsDisplay = YES;
	if ( self.delegate )
		[self.delegate fragmentCellClicked:self];
}

- (void)doubleClick:(id)sender {
	[VMPNotificationCenter postNotificationName:VMPNotificationFragmentDoubleClicked
										 object:self
									   userInfo:@{@"id":self.fragment.id}];
}

- (void)selectIfIdDoesMatch:(VMId*)fragId exclusive:(BOOL)exclusive {
	if ( [fragId isEqualToString:self.fragment.id] ) {
		self.selected = YES;
	} else if (exclusive) {
		self.selected = NO;
	}
}


- (void)audioFragmentFired:(NSNotification*)notification {
	self.playing = [self.fragment containsId:((VMAudioFragment*)(notification.userInfo)[@"audioFragment"]).id];
}

- (void)drawPositionMark:(int)position {
	//
	//	position index
	//
	if (self.animating) return;		//	do not draw position mark while animating
	BeginGC
	SaveGC {
		[smallShadow_static_ set];
		[VMPColorBy(.4, .4, .4, 1.) setFill];
		NSRect positionTextRect = NSMakeRect( 0, 0, ( position>=10 ? 25 : 15), 12);
		NSBezierPath *zabton = [NSBezierPath bezierPathWithRoundedRect:positionTextRect
															   xRadius:vmpCellCornerRadius
															   yRadius:vmpCellCornerRadius];
		[zabton fill];
		NSString *indexString = (position >= 0) ? [NSString stringWithFormat:@"%d", position] : @"~";
		[indexString drawInRect:positionTextRect withAttributes:positionTextAttributes_static_];
	} RestoreGC
	
}

@end






#pragma mark -	
#pragma mark *** Fragment Header ***
#pragma mark -
/*---------------------------------------------------------------------------------
 *
 *
 *	Fragment Header
 *
 *
 *---------------------------------------------------------------------------------*/
@implementation VMPFragmentHeader

+ (VMPFragmentHeader*)fragmentHeaderWithFragment:(VMFragment*)frag
									   frame:(NSRect)frame
									delegate:(id<VMPFragmentGraphDelegate>)delegate {
	VMPFragmentHeader *fh = AutoRelease([[VMPFragmentHeader alloc] initWithFrame:frame]);
	fh.fragment = frag;
	fh.delegate = delegate;
	
	return fh;
}


- (void)setFragment:(VMFragment *)frag {	//	override
	[super setFragment:frag];
	if ( ! frag ) return;
	NSColor *c0 = [NSColor colorForDataType:frag.type];
	NSColor *c1 = [[c0 colorModifiedByHueOffset:-.01 saturationFactor:0.9 brightnessFactor:1.1] colorWithAlphaComponent:0.5];
	NSColor *c2 = [[c0 colorModifiedByHueOffset: .01 saturationFactor:1.0 brightnessFactor:0.9] colorWithAlphaComponent:1.0];
	self.backgroundGradient = AutoRelease([[NSGradient alloc] initWithStartingColor:c2
																		endingColor:c1]);
}


-(void)drawRect:(NSRect)dirtyRect {
	BeginGC
	
	NSRect			contentRect = self.contentRect;
	if ( contentRect.size.height == 0 || contentRect.size.width == 0 ) return;	//	insurance
	NSBezierPath	*headerPath;
	//
	//	frame
	//
	SaveGC {
		CGFloat			cornerRadius = MIN( contentRect.size.width, contentRect.size.height ) * 0.5;
		if ( self.selected ) {
			headerPath = [NSBezierPath bezierPathWithRoundedRect:CGRectInset( contentRect, 1.5, 1.5)
														 xRadius:cornerRadius yRadius:cornerRadius];
			headerPath.lineWidth = 3.;
		} else {
			headerPath = [NSBezierPath bezierPathWithRoundedRect:contentRect
														 xRadius:cornerRadius yRadius:cornerRadius];
			headerPath.lineWidth = 0.5;
		}
		
		//
		//	label text
		//
		if ( contentRect.size.width >= contentRect.size.height ) {
			//	horizontal header
			[self.backgroundGradient drawInBezierPath:headerPath angle:0];
			[self.fragment.id drawInRect:CGRectInset(contentRect, 10., 4.) withAttributes:headerTextAttributes_static_];
			
			
		} else {
			//	vertical header
			[self.backgroundGradient drawInBezierPath:headerPath angle:270];
			if ( ! self.animating ) [self.fragment.id drawVerticalInRect:CGRectInset(contentRect, 0, 5. )
														  withAttributes:headerTextAttributes_static_];
		}
		if ( ! self.animating ) [defaultShadow_static_ set];
		[[[NSColor colorForDataType:self.fragment.type] colorWithAlphaComponent:0.5] setStroke];
		[headerPath stroke];
	} RestoreGC
	int position = self.position;
	if ( position != 0 )
		[self drawPositionMark:position];

}

@end







#pragma mark -
#pragma mark *** Fragment Cell ***
#pragma mark -
/*---------------------------------------------------------------------------------
 *
 *
 *	Fragment Cell
 *
 *
 *---------------------------------------------------------------------------------*/


@implementation VMPFragmentCell

+ (VMPFragmentCell*)fragmentCellWithFragment:(VMFragment*)frag
									   frame:(NSRect)frame
									delegate:(id<VMPFragmentGraphDelegate>)delegate {
	VMPFragmentCell *cc = AutoRelease([[VMPFragmentCell alloc] initWithFrame:frame]);
	cc.fragment = frag;
	cc.delegate = delegate;
	
	return cc;
}


- (void)setFragment:(VMFragment *)frag {	//	override // NOTE: frame must be set before calling this method.
	[super setFragment:frag];
	if ( !frag )
		return;
	
	//	we assume that the cell width does not change.
	textFrameRectCache = [self rectForText:self.fragment.id
								attributes:idTextAttributes_static_
								  maxWidth:self.contentRect.size.width - 12];
	
	NSColor *c0 = [NSColor backgroundColorForDataType:frag.type];
	NSColor *c1 = [[c0 colorModifiedByHueOffset:-.05 saturationFactor:0.9 brightnessFactor:1.1] colorWithAlphaComponent:0.5];
	NSColor *c2 = [[c0 colorModifiedByHueOffset:+.05 saturationFactor:1.0 brightnessFactor:0.9] colorWithAlphaComponent:1.0];
	self.backgroundGradient = AutoRelease([[NSGradient alloc] initWithStartingColor:c1
																		endingColor:c2]);
}


#pragma mark public

#pragma mark drawing
- (void)drawRect:(NSRect)rect {
	if ( self.contentRect.size.width == 0 || self.contentRect.size.height == 0 ) return;
	if ( self.fragment == nil ) return;
	
	BeginGC
	
	//
	//	the cell frame
	//
	SaveGC {
		NSColor *baseColor = [NSColor colorForDataType:self.fragment.type];
		[[baseColor colorWithAlphaComponent:0.5] setStroke];
		NSBezierPath *cellPath;
		if (!self.selected) {
			cellPath = [NSBezierPath bezierPathWithRoundedRect:self.contentRect
													   xRadius:vmpCellCornerRadius
													   yRadius:vmpCellCornerRadius];
			cellPath.lineWidth = 0.5;
		} else {
			cellPath = [NSBezierPath bezierPathWithRoundedRect:CGRectInset(self.contentRect, 1.5, 1.5)
													   xRadius:vmpCellCornerRadius
													   yRadius:vmpCellCornerRadius];
			cellPath.lineWidth = 3.;
		}
		if ( ! self.isPlaying ) {
			[self.backgroundGradient drawInBezierPath:cellPath angle:60];
		} else {
			NSGradient *pg = [[NSGradient alloc]
			 initWithStartingColor:[baseColor colorModifiedByHueOffset:0.01 saturationFactor:0.5 brightnessFactor:1.5]
			 endingColor:[baseColor colorModifiedByHueOffset:-0.01 saturationFactor:0.5 brightnessFactor:1.2]];
			[pg drawInBezierPath:cellPath angle:60];
			Release( pg );
		}
		if ( ! self.animating ) [defaultShadow_static_ set];
		[cellPath stroke];
	} RestoreGC
	
	//
	//	text
	//
	if ( self.contentRect.size.height > 10 && self.fragment ) {
		SaveGC {
			CGFloat verticalOffset = ( self.contentRect.size.height - textFrameRectCache.size.height ) * 0.5;
			if ( verticalOffset < 0 ) verticalOffset = 0;
			[self.fragment.id drawInRect:NSMakeRect(self.contentRect.origin.x + 6.,
													self.contentRect.origin.y + verticalOffset,
													self.contentRect.size.width  - 12.,
													self.contentRect.size.height - verticalOffset )
						  withAttributes:idTextAttributes_static_];
		} RestoreGC
	}
	
	int position = self.position;
	if ( position != 0 )
		[self drawPositionMark:position];
}

- (NSRect)rectForText:(VMString*)text attributes:(NSDictionary*)attributes maxWidth:(CGFloat)maxWidth {
	NSAttributedString *str = [[NSAttributedString alloc] initWithString:text attributes:attributes];
	NSRect textFrameRect = [str boundingRectWithSize:NSMakeSize( maxWidth, CGFLOAT_MAX )
											 options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading];
	Release( str );
	return textFrameRect;
}

@end
