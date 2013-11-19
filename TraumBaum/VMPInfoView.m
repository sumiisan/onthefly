//
//  VMPInfoViewController.m
//
//  Created by sumiisan on 2013/04/03.
//
//
#import <AVFoundation/AVFoundation.h>

#import "VMPInfoView.h"
#import "MultiPlatform.h"
#import "VMPSongPlayer.h"
#import "VMAppDelegate.h"
#import "VMPScrollViewClipper.h"
//#import "KTOneFingerRotationGestureRecognizer-master/KTOneFingerRotationGestureRecognizer.h"
#import "VMPRainyView.h"

@implementation VMPInfoView

static const int kNumberOfSkins = 4;


#define ARImageView(fileName) [[[UIImageView alloc] initWithImage:[UIImage imageNamed:fileName]] autorelease]

/*
- (void)newButtonAt:(CGPoint)position type:(NSString*)type tag:(NSInteger)tag {
		
	UIButton *bt = [UIButton buttonWithType:UIButtonTypeCustom];
	
	[bt setImage:[UIImage imageNamed:[NSString stringWithFormat:@"iPhone-UI/%@_button_up.png",type]]
		forState:UIControlStateNormal];
	UIImage *downImage = [UIImage imageNamed:[NSString stringWithFormat:@"iPhone-UI/%@_button_dn.png",type]];
	[bt setImage:downImage forState:UIControlStateHighlighted];
	[bt setImage:downImage forState:UIControlStateSelected];
	
	bt.frame = CGRectMake( position.x, position.y, downImage.size.width * 0.5, downImage.size.height * 0.5 );
	bt.tag = tag;

	[bt addTarget:self action:@selector(buttonTouched:) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:bt];
}

- (void)selectButtonWithTag:(NSInteger)tag {
	for( UIView *view in self.view.subviews ) {
		if( ! [view isKindOfClass:[UIButton class]] ) continue;
		if ( view.tag == tag ) {
			[((UIButton*)view) setSelected: YES];
		} else {
			[((UIButton*)view) setSelected: NO];
		}
	}
}
*/

- (void)setBackgroundMode:(BOOL)enabled {
	NSLog(@"Setting background playback to:%@", (enabled ? @"YES" : @"NO"));
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"doesPlayInBackground"];
	[[VMAppDelegate defaultAppDelegate] setAudioBackgroundMode];
}

- (IBAction)buttonTouched:(id)sender {
	UIButton *b = sender;
	BOOL closeDialog = YES;
	
	switch ( b.tag ) {
			
			//
			//	open webpage
			//
		case 100:
		case '_web':
			[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://traumbaum.aframasda.com/"]];
			closeDialog = NO;
			break;
			
			//
			//	reset song
			//
		case 101:
		case 'rset':
			[[VMAppDelegate defaultAppDelegate] reset];
			break;
			
			//
			//	background play
			//
		case 102: {	//	switch
			UISwitch *sw = sender;
			[self setBackgroundMode:sw.isOn];
			closeDialog = NO;
			break;
		}
			
		case 'plyb': {	//	toggle button
			BOOL doesPlayInBackGround = [[NSUserDefaults standardUserDefaults] boolForKey:@"doesPlayInBackground"];
			doesPlayInBackGround = ! doesPlayInBackGround;
			[self setBackgroundMode:doesPlayInBackGround];
			b.selected = doesPlayInBackGround;
			[self viewWithTag:'chck'].hidden = ( ! doesPlayInBackGround );
			closeDialog = NO;
			break;
		}
/*
		case 103:	{	//	dark ui
			BOOL darkBG = self.darkBGSwitch.isOn;
			[[NSUserDefaults standardUserDefaults] setBool:darkBG forKey:@"darkBgEnabled"];
			[self.delegate setSkinIndex:(darkBG ? 1 : 0)];

			closeDialog = NO;
			break;
		}
*/
		case 104:
		case 'rtrn':
			//	nothing to do.
			break;
			
	}
	
	if (closeDialog) {
//		[DEFAULTSONGPLAYER setDimmed:NO];
//		[self dismissModalViewControllerAnimated:YES];
		[self hideView];
	}
	
}

- (void)showView {
	self.alpha = 0;
	self.backgroundPlaySwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"doesPlayInBackground"];
	self.backgroundColor = [UIColor colorWithWhite:1. alpha:0.7];
	
	
	
	CGRect screenRect = [UIScreen mainScreen].bounds;
	CGFloat vOffset = ( screenRect.size.height - self.frame.size.height ) * 0.5;
	
	self.frame = CGRectMake(0, vOffset, self.frame.size.width, self.frame.size.height );
	NSLog(@"%@", NSStringFromCGRect(self.frame));
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.5];
	self.alpha = 1;
	[UIView commitAnimations];
}

- (void)hideView {
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:0.5];
	self.alpha = 0.;
	[UIView commitAnimations];
	[self performSelector:@selector(dismissView) withObject:nil afterDelay:0.6];
}

- (void)dismissView {
	[self removeFromSuperview];
}

- (id)init {
    self = [super init];
    if (self) {
		
#if 0
	
		//	no fancy button bg's for now.
		
		
		CGFloat vOffs = ( Is4InchIPhone ? 88 : 0 );
		for (int i = 0; i < 4; ++i ) {
			VMPRainyView *db = AutoRelease([[VMPRainyView alloc] initWithFrame:CGRectMake(0, 210 + i*50 + vOffs, 320, 45)]);
			db.alpha = 0.5;
			[self.view addSubview:db];
			[self.view sendSubviewToBack:db];
		}
#endif
		
		
		
		
		//self.view.frame = CGRectMake(0, vOffs, 320, 480);
				
		
#if 0
		/*
		
		
		depreciated due to support iOS7 ready interface.
		we use a nib instead.
		
		
		*/
		//	bg
		UIImageView *bg = ARImageView(@"iPhone-UI/info_phone.jpg");
		bg.frame = CGRectMake( 0, -25 + vOffs, 320, 568 );
		[self.view addSubview:bg];
		
		//	place buttons;
		[self newButtonAt:CGPointMake(  70, 178 + vOffs ) type:@"long" tag:'_web'];
		[self newButtonAt:CGPointMake(  70, 223 + vOffs ) type:@"long" tag:'rset'];
		[self newButtonAt:CGPointMake(  70, 268 + vOffs ) type:@"long" tag:'plyb'];
		

		[self newButtonAt:CGPointMake( 142, 427 + vOffs ) type:@"round" tag:'rtrn'];
		
		//

		UIImageView *check = ARImageView(@"iPhone-UI/check.png");
		check.frame = CGRectMake( 40, 272 + vOffs, 20, 20 );
		check.tag = 'chck';
		BOOL bgplay =  [[NSUserDefaults standardUserDefaults] boolForKey:@"doesPlayInBackground"];
		check.hidden = ! bgplay;
		((UIButton*)[self.view viewWithTag:'plyb']).selected = bgplay;
		[self.view addSubview:check];
		
		int currentSkinIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"skinIndex"];
		if ( currentSkinIndex < 0 || currentSkinIndex >= kNumberOfSkins ) currentSkinIndex = 0;	//	insurance

		
		UIScrollView *sv = [[[UIScrollView alloc] initWithFrame:CGRectMake(0, 0/*335*/, 320, 79)] autorelease];
		sv.tag = 'scrl';
		
		VMPScrollViewClipper *svc = [[[VMPScrollViewClipper alloc] initWithFrame:CGRectMake( 0, 335, 320, 79 )] autorelease];
		[svc addSubview:sv];
		svc.scrollView = sv;
		
		[self.view addSubview:svc];
		
		sv.scrollEnabled = YES;
		sv.pagingEnabled = YES;
		sv.clipsToBounds = NO;
		sv.contentSize = CGSizeMake( kNumberOfSkins * 140, 79);
		sv.bounds = CGRectMake(0, 0, 140, 79);
		sv.showsVerticalScrollIndicator = sv.showsHorizontalScrollIndicator = NO;
		sv.delegate = self;
		sv.contentOffset = CGPointMake( currentSkinIndex * 140, 0 );
		
		for( int skin =0; skin < kNumberOfSkins; ++skin ) {
			NSString *skinImageName = [NSString stringWithFormat:@"iPhone-UI/preview_skin%d.png", skin];
			UIImageView *skimg = ARImageView( skinImageName );
			UIImageView *frimg = ARImageView( @"iPhone-UI/square_button_up.png" );
			skimg.tag = 'skn0' + skin;
			frimg.tag = 'frm0' + skin;
			skimg.frame = CGRectMake(skin * 140 +8, 3, 124, 72 );
			frimg.frame = CGRectMake(skin * 140 +5, 0, 130, 79 );
			skimg.alpha = skin == currentSkinIndex ? 1 : 0.35;
			[sv addSubview:skimg];
			[sv addSubview:frimg];
		}
		
		UIImageView *centerFrame = ARImageView( @"iPhone-UI/square_button_dn.png");
		centerFrame.frame = CGRectMake( 95, 335, 130, 78.5 );
		[self.view addSubview:centerFrame];
		
#endif
		
		
				
	//	[DEFAULTSONGPLAYER setDimmed:YES];
		/*
		KTOneFingerRotationGestureRecognizer *ofrgr = [[KTOneFingerRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotating:)];
		[self.view addGestureRecognizer:ofrgr];
		Release(ofrgr);	*/
		[self attachGestureRecognizer];
    }
    return self;
}

- (void)attachGestureRecognizer {
	UITapGestureRecognizer *tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleTrackView:)];
	tgr.numberOfTouchesRequired =
#if TARGET_IPHONE_SIMULATOR
	1;
#else
	3;
#endif
	tgr.numberOfTapsRequired = 3;
	[self addGestureRecognizer:tgr];
	Release(tgr);
}

/*
- (void)rotating:(KTOneFingerRotationGestureRecognizer *)recognizer {
	double angle = recognizer.rotation;
	NSLog( @"angle: %.2f", angle );
}*/

- (void)willMoveToSuperview:(UIView *)newSuperview {

//- (void)viewWillAppear:(BOOL)animated {
	self.backgroundPlaySwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"doesPlayInBackground"];
	self.backgroundColor = [UIColor colorWithWhite:1. alpha:0.6];
//	self.darkBGSwitch.on         = [[NSUserDefaults standardUserDefaults] boolForKey:@"darkBgEnabled"];
	
//	[super viewWillAppear:animated];
	[super willMoveToSuperview:newSuperview];
}

- (void)toggleTrackView:(id)sender {
	
	if ( supressToggleTrackViewUntil > [NSDate timeIntervalSinceReferenceDate]) return;
	supressToggleTrackViewUntil = [NSDate timeIntervalSinceReferenceDate] + 0.5;
	
	VMPTrackView *tv = (VMPTrackView*)[self viewWithTag:'trkV'];
	if ( tv ) {
		//	hide
		DEFAULTSONGPLAYER.trackView = nil;
		[tv removeFromSuperview];
		return;
	}
	//	show;
	tv = AutoRelease([[VMPTrackView alloc] initWithFrame:self.frame]);
	tv.tag = 'trkV';
	[self addSubview:tv];
//	[DEFAULTSONGPLAYER setDimmed:NO];

	DEFAULTSONGPLAYER.trackView = tv;
}

- (void)dealloc {
//	VMNullify(scrollContentView);
	[super dealloc];
}

//	delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//	int centerSkin = ( scrollView.contentOffset.x +70 ) / 140;
	for( int skin = 0; skin < kNumberOfSkins; ++skin ) {
		UIImageView *skinView = (UIImageView*)[self viewWithTag:'skn0'+skin];
		double dist = fabs( skinView.frame.origin.x - scrollView.contentOffset.x );
		skinView.alpha = dist > 200 ? 0. : 1 - dist * 0.005;
	}
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	int selectedSkin = scrollView.contentOffset.x / 140;
	[self.delegate setSkinIndex:selectedSkin];
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if ( self ) {
		[self attachGestureRecognizer];
	}
	return self;
}

/*
- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
    if (self) {
		[self attachGestureRecognizer];

    }
	return self;
}*/
/*
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.scrollContentView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
	NSLog(@"End zoom %.2f",scale);
}
*/
@end
