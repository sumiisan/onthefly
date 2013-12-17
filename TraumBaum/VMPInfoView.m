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
#import "VMViewController.h"
#import "VMPFrontView.h"
//#import "KTOneFingerRotationGestureRecognizer-master/KTOneFingerRotationGestureRecognizer.h"
//#import "VMPRainyView.h"
#import "VMPMultiLanguage.h"

@implementation VMPInfoView

//static const int kNumberOfSkins = 4;
#define DROPBOX_MESSAGE_URL @"https://dl.dropboxusercontent.com/u/147605/tbmessage.txt"

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
		case 'rset': {
			closeDialog = NO;

			UIAlertView *av = [[UIAlertView alloc] initWithTitle:[VMPMultiLanguage confirmTitle]
														 message:[VMPMultiLanguage reallyRestartMessage]
														delegate:self
											   cancelButtonTitle:[VMPMultiLanguage noString]
											   otherButtonTitles:[VMPMultiLanguage yesString], nil];
			
			[av show];
			[av release];
			
	//		[[VMAppDelegate defaultAppDelegate] reset];
			break;
		}
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
		[self closeView];
	}
	
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if( buttonIndex == 1) {
		self.statisticsLabel.text = @"";
		[self closeView];
		[[VMAppDelegate defaultAppDelegate] reset];
	}
}

- (void)showView {
	self.alpha = 0;
	
	[self retrieveMessageFile];
	
	self.backgroundPlaySwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"doesPlayInBackground"];
	self.backgroundColor = [UIColor clearColor];
	
//	CGRect screenRect = [UIScreen mainScreen].bounds;
//	CGFloat vOffset = ( screenRect.size.height - self.frame.size.height ) * 0.5;
	
	self.frame = [UIScreen mainScreen].bounds;
	NSLog(@"frame:%@",NSStringFromCGRect(self.frame));
	
	UIView		*bgSwitchBG		= [self viewWithTag:109];
	UIView		*titlePane		= [self viewWithTag:110];
	UIView		*controlPane	= [self viewWithTag:111];
	UILabel		*infoField		= (UILabel*)[self viewWithTag:112];
	UIButton	*resetButton	= (UIButton*)[self viewWithTag:101];
	UIButton	*backButton		= (UIButton*)[self viewWithTag:104];
	
	//	adjust titlePane postiion
//	titlePane.center = [VMAppDelegate defaultAppDelegate].viewController.frontView.holeCenter;
	CGPoint center = [VMAppDelegate defaultAppDelegate].viewController.frontView.holeCenter;
	titlePane.frame = CGRectMake(0,center.y-110,320,220);
	controlPane.frame = CGRectMake(0, self.bounds.size.height-controlPane.frame.size.height,
								   320, controlPane.frame.size.height);
	
	CAGradientLayer *g0 = [CAGradientLayer layer];
	g0.frame = self.frame;
	g0.colors = [NSArray arrayWithObjects:
				 (id)[UIColor colorWithWhite:.87 alpha:.7].CGColor,
				 (id)[UIColor colorWithWhite:.87 alpha:.6].CGColor,
				 (id)[UIColor colorWithWhite:.87 alpha:.5].CGColor,
				 (id)[UIColor colorWithWhite:.87 alpha:.4].CGColor,
				 nil];
	g0.locations = @[ @0.0, @0.1, @0.9, @1.0 ];
	
	[self.layer insertSublayer:g0 atIndex:0];
	
	CAGradientLayer *g1 = [CAGradientLayer layer];
	g1.frame = CGRectMake( 0, -40, 320, titlePane.bounds.size.height + 80 );
	g1.colors = [NSArray arrayWithObjects:
				 (id)[UIColor colorWithWhite:.99 alpha:.0].CGColor,
				 (id)[UIColor colorWithWhite:.99 alpha:.5].CGColor,
				 (id)[UIColor colorWithWhite:.99 alpha:.6].CGColor,
				 (id)[UIColor colorWithWhite:.99 alpha:.6].CGColor,
				 (id)[UIColor colorWithWhite:.99 alpha:.5].CGColor,
				 (id)[UIColor colorWithWhite:.99 alpha:.0].CGColor,
				 nil];
	g1.locations = @[ @0.0, @0.1, @0.2, @0.8, @0.9, @1.0 ];
	
//	[titlePane.layer insertSublayer:g1 atIndex:0];
	
	NSArray *ar = [NSArray arrayWithObjects:
				   (id)[UIColor colorWithWhite:.70 alpha:.1].CGColor,
				   (id)[UIColor colorWithWhite:.99 alpha:.3].CGColor,
				   (id)[UIColor colorWithWhite:.99 alpha:.6].CGColor,
				   (id)[UIColor colorWithWhite:.99 alpha:.6].CGColor,
				   (id)[UIColor colorWithWhite:.99 alpha:.3].CGColor,
				   (id)[UIColor colorWithWhite:.70 alpha:.1].CGColor,
				   nil];
	NSArray *lc = @[ @0.0, @0.03, @0.06, @0.94, @0.97, @1.0 ];
	
	CAGradientLayer *g2 = [CAGradientLayer layer];
	CAGradientLayer *g3 = [CAGradientLayer layer];
	CAGradientLayer *g4 = [CAGradientLayer layer];
	CAGradientLayer *g5 = [CAGradientLayer layer];
	g2.frame = bgSwitchBG.bounds;
	g3.frame = resetButton.bounds;
	g4.frame = backButton.bounds;
	g5.frame = infoField.bounds;
	g2.colors = ar;
	g3.colors = ar;
	g4.colors = ar;
	g5.colors = ar;
	g2.locations = lc;
	g3.locations = lc;
	g4.locations = lc;
	g5.locations = lc;

	[bgSwitchBG.layer insertSublayer:g2 atIndex:0];
	[resetButton.layer insertSublayer:g3 atIndex:0];
	[backButton.layer insertSublayer:g4 atIndex:0];
	[infoField.layer insertSublayer:g5 atIndex:0];
	infoField.hidden = YES;
	
//	self.frame = CGRectMake(0, vOffset, self.frame.size.width, self.frame.size.height );
//	NSLog(@"%@", NSStringFromCGRect(self.frame));
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:1.];
	self.alpha = 1;
	[UIView commitAnimations];
	[DEFAULTSONGPLAYER setDimmed:YES];
	[self updateStats:nil];
}

- (void)retrieveMessageFile {
	NSURLRequest *req = [NSURLRequest requestWithURL:
						 [NSURL URLWithString:DROPBOX_MESSAGE_URL]
						 ];
	NSURLConnection *conn = [NSURLConnection connectionWithRequest:req delegate:self];
	if( !conn )
		NSLog(@"failed to connect dropbox");
	
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	NSString *wholeText = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSString *dismissed = [[NSUserDefaults standardUserDefaults] stringForKey:@"dismissedMessage"];
	NSArray *lines = [wholeText componentsSeparatedByString:@"\n"];
	NSString *preferredLanguage = [VMPMultiLanguage language];
	NSString *message = nil;
	for( NSString *line in lines) {
		NSArray *c = [line componentsSeparatedByString:@"|"];
		if ( [c[0] isEqualToString:preferredLanguage])  {
			message = c[1];
			break;
		}
	}
	
	UILabel	*infoField = (UILabel*)[self viewWithTag:112];
	infoField.text = message;
	if ( message.length > 0 && ! [message isEqualToString:dismissed] ) {
		infoField.hidden = NO;
	} else {
		infoField.hidden = YES;
	}
}

- (void)updateStats:(id)sender {
	VMInt minutes = DEFAULTSONG.songStatistics.secondsPlayed / 60;
	VMFloat percent = DEFAULTSONG.songStatistics.percentsPlayed;
	
	
	if( minutes > 1440 ) {
		self.statisticsLabel.text = [NSString stringWithFormat:@"%ld %02ld:%02ld / %.1f%%",
									 minutes / 1440,
									 ( minutes / 60 ) % 24,
									 minutes % 60,
									 percent ];
	} else {
		self.statisticsLabel.text = [NSString stringWithFormat:@"%2ld:%02ld / %.1f%%",
									 ( minutes / 60 ) % 24,
									 minutes % 60,
									 percent ];
	}
	[self performSelector:@selector(updateStats:) withObject:nil afterDelay:3.];
}

- (void)closeView {
	[DEFAULTSONGPLAYER setDimmed:NO];
	[UIView animateWithDuration:1.0f
					 animations:^(){
						 self.alpha = 0.;
					 }
					 completion:^(BOOL finished){
						 if( finished ) [self removeFromSuperview];
					 }];
	
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateStats:) object:nil];
}

- (id)init {
    self = [super init];
    if (self) {
		[self initViewAndRecognizer];
    }
    return self;
}

- (void)initViewAndRecognizer {
/*	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tweetFetched:)
												 name:TWITTERTIMELINEFETCHED_NOTIFICATION
											   object:nil];
*/
	
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
- (void)tweetFetched:(NSNotification*)notification {
	NSDictionary *tl = notification.userInfo;
	UILabel		*infoField		= (UILabel*)[self viewWithTag:112];
	infoField.text = tl.description;
}
*/
/*
- (void)rotating:(KTOneFingerRotationGestureRecognizer *)recognizer {
	double angle = recognizer.rotation;
	NSLog( @"angle: %.2f", angle );
}*/

- (void)willMoveToSuperview:(UIView *)newSuperview {

	self.backgroundPlaySwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"doesPlayInBackground"];
	self.backgroundColor = [UIColor colorWithWhite:1. alpha:0.6];
//	self.darkBGSwitch.on         = [[NSUserDefaults standardUserDefaults] boolForKey:@"darkBgEnabled"];
	
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
	[DEFAULTSONGPLAYER setDimmed:NO];
	DEFAULTSONGPLAYER.trackView = tv;
}

- (void)dealloc {
//	VMNullify(scrollContentView);
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}


//	delegate
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//	int centerSkin = ( scrollView.contentOffset.x +70 ) / 140;
/*	for( int skin = 0; skin < kNumberOfSkins; ++skin ) {
		UIImageView *skinView = (UIImageView*)[self viewWithTag:'skn0'+skin];
		double dist = fabs( skinView.frame.origin.x - scrollView.contentOffset.x );
		skinView.alpha = dist > 200 ? 0. : 1 - dist * 0.005;
	}*/
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	int selectedSkin = scrollView.contentOffset.x / 140;
	[self.delegate setSkinIndex:selectedSkin];
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if ( self ) {
		[self initViewAndRecognizer];
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
