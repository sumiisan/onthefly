//
//  VMPInfoViewController.m
//
//  Created by sumiisan on 2013/04/03.
//
//
#import <AVFoundation/AVFoundation.h>

#import "VMPInfoView.h"
#import "MultiPlatform.h"
#import "VMScoreEvaluator.h"
#import "VMSong.h"
#import "VMPSongPlayer.h"
#import "VMAppDelegate.h"
#import "VMPScrollViewClipper.h"
#import "VMViewController.h"
#import "VMPFrontView.h"
#import "VMPMultiLanguage.h"
#import "VMTraumbaumUserDefaults.h"
#import "VMPSongListView.h"

@implementation VMPInfoView

//static const int kNumberOfSkins = 4;
#define DROPBOX_MESSAGE_URL @"https://dl.dropboxusercontent.com/u/147605/tbmessage.txt"

#define ARImageView(fileName) [[[UIImageView alloc] initWithImage:[UIImage imageNamed:fileName]] autorelease]

- (void)setBackgroundMode:(BOOL)enabled {
	NSLog(@"Setting background playback to:%@", (enabled ? @"YES" : @"NO"));
	[VMTraumbaumUserDefaults setBackgroundPlayback:enabled];
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
		case '_web': {
			if ( [[[VMVmsarcManager defaultManager] propertyOfCurrentVMS:VMSCacheKey_BuiltIn] boolValue] ) {
				[[UIApplication sharedApplication]
				 openURL:[NSURL URLWithString:
						  [NSString stringWithFormat:@"http://traumbaum.aframasda.com/?l=%@",
						   [VMPMultiLanguage language]]]];
			} else {
				[[UIApplication sharedApplication]
				 openURL:[NSURL URLWithString:DEFAULTSONG.websiteURL]];
			}
			closeDialog = NO;
			break;
		}
			//
			//	reset song
			//
		case 101:
		case 'rset': {
			closeDialog = NO;
			self.statisticsLabel.hidden = NO;
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
			BOOL doesPlayInBackGround = [VMTraumbaumUserDefaults backgroundPlayback];
			doesPlayInBackGround = ! doesPlayInBackGround;
			[self setBackgroundMode:doesPlayInBackGround];
			b.selected = doesPlayInBackGround;
			[self viewWithTag:'chck'].hidden = ( ! doesPlayInBackGround );
			closeDialog = NO;
			break;
		}
		case 104:
		case 'rtrn':
			//	nothing to do.
			break;
			
		case 112:
			[VMTraumbaumUserDefaults setLastDismissedMessage:b.titleLabel.text];
			b.hidden = YES;
			closeDialog = NO;
			//	message
			break;
			
		case 120: {
			//	song list
			CGFloat h = self.bounds.size.height - 51;
			VMPSongListView *listView = [[[VMPSongListView alloc]
										  initWithFrame:CGRectMake(320, 0, self.bounds.size.width, h)] autorelease];
			listView.alpha = 0.5;
			listView.tag = 700;
			[self addSubview:listView];
//			listView.frame = CGRectMake(320, 0, self.bounds.size.width, h);
			[UIView beginAnimations:nil context:nil];
			[UIView setAnimationDuration:.3];
			listView.alpha = 1.;
			listView.frame = CGRectMake(0, 0, self.bounds.size.width, h);
			[UIView commitAnimations];
///			[[VMAppDelegate defaultAppDelegate].viewController presentViewController:VMPSongListView animated:YES completion:nil];
			closeDialog = NO;

			break;
		}
	}
	
	if (closeDialog) {
		[self closeView];
	}
	
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	self.statisticsLabel.hidden = YES;
	if( buttonIndex == 1) {
		self.statisticsLabel.text = @"";
		[self closeView];
		[[VMAppDelegate defaultAppDelegate] reset];
	}
}

- (void)showView {
	self.alpha = 0;
	
	[self retrieveMessageFile];
	
	self.backgroundPlaySwitch.on = [VMTraumbaumUserDefaults backgroundPlayback];
	self.backgroundColor = [UIColor clearColor];
		
	self.frame = [UIScreen mainScreen].bounds;
	BOOL externalVMSMode = [[VMVmsarcManager defaultManager] externalVMSMode];
	
	CGFloat b = 1.;
	[DEFAULTEVALUATOR.timeManager.backgroundColor getHue:nil saturation:nil brightness:&b alpha:nil];
	BOOL isDarkBG = ( b < 0.3 );
	
	UIView		*bgSwitchBG		= [self viewWithTag:109];
	UIView		*titlePane		= [self viewWithTag:110];
	
	UIView		*controlPane	= [self viewWithTag:111];
	UIButton	*infoButton		= (UIButton*)[self viewWithTag:112];
	UIButton	*songListButton	= (UIButton*)[self viewWithTag:120];
	UIButton	*resetButton	= (UIButton*)[self viewWithTag:101];
	UIButton	*backButton		= (UIButton*)[self viewWithTag:104];
	
	UIButton	*websiteButton	= (UIButton*)[self viewWithTag:100];
	
	if( externalVMSMode ) {
		UILabel		*subtitleLabel	= (UILabel*)[self viewWithTag:600];
		UILabel		*titleLabel		= (UILabel*)[self viewWithTag:601];
		UILabel		*versionLabel	= (UILabel*)[self viewWithTag:602];
		UILabel		*creditsLabel	= (UILabel*)[self viewWithTag:603];
		
		subtitleLabel.text = DEFAULTSONG.songDescription;
		titleLabel.text = DEFAULTSONG.songName;
		versionLabel.text = DEFAULTSONG.versionString;
		creditsLabel.text = [NSString stringWithFormat:@"%@\n%@", DEFAULTSONG.artist, DEFAULTSONG.copyright];
	}
		
	CGPoint center = [VMAppDelegate defaultAppDelegate].viewController.frontView.holeCenter;
	titlePane.frame = CGRectMake(0,center.y-60,320,121);
	controlPane.frame = CGRectMake(0, self.bounds.size.height-controlPane.frame.size.height,
								   320, controlPane.frame.size.height);
	
	CAGradientLayer *g0 = [CAGradientLayer layer];
	g0.frame = self.frame;
	CGFloat bgBrightness = isDarkBG ? 0.13 : 0.87;
	CGFloat textBrightness = isDarkBG ? 0.8 : 0.2;
	CGFloat panelBGBrightness = isDarkBG ? 0.1 : 1.;
	VMPColor *textColor = VMPColorBy(textBrightness, textBrightness, textBrightness, 1.);
	VMPColor *panelColor = VMPColorBy(panelBGBrightness, panelBGBrightness, panelBGBrightness, 0.5 );
	g0.colors = [NSArray arrayWithObjects:
				 (id)[UIColor colorWithWhite:bgBrightness alpha:.5].CGColor,
				 (id)[UIColor colorWithWhite:bgBrightness alpha:.6].CGColor,
				 (id)[UIColor colorWithWhite:bgBrightness alpha:.7].CGColor,
				 (id)[UIColor colorWithWhite:bgBrightness alpha:.5].CGColor,
				 nil];
	g0.locations = @[ @0.0, @0.03, @0.97, @1.0 ];
	
	[self.layer insertSublayer:g0 atIndex:0];

	infoButton.hidden = YES;
	infoButton.titleLabel.textColor = textColor;
	infoButton.titleLabel.textAlignment = NSTextAlignmentCenter;
	infoButton.backgroundColor = panelColor;
	resetButton.backgroundColor = panelColor;
	
	songListButton.hidden = [VMVmsarcManager defaultManager].vmsCacheTable.count < 2;
	songListButton.backgroundColor = panelColor;
	[songListButton setTitle:[VMPMultiLanguage songlistTitle] forState:UIControlStateNormal];
	[songListButton setTitle:[VMPMultiLanguage songlistTitle] forState:UIControlStateSelected];
	backButton.backgroundColor = panelColor;
	bgSwitchBG.backgroundColor = panelColor;
	
	if( DEFAULTSONG.websiteURL.length > 0 ) {
		NSURL *url = [NSURL URLWithString:DEFAULTSONG.websiteURL];
		websiteButton.titleLabel.text = [url.host stringByAppendingPathComponent:url.path];
		websiteButton.hidden = NO;
	} else {
		websiteButton.hidden = YES;
	}

	self.statisticsLabel.hidden = YES;
	
    for (UIView *subview in titlePane.subviews) if( subview.class == [UILabel class] ) ((UILabel*)subview).textColor = textColor;
    for (UIView *subview in bgSwitchBG.subviews) if( subview.class == [UILabel class] ) ((UILabel*)subview).textColor = textColor;

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
	
	UIButton *infoButton = (UIButton*)[self viewWithTag:112];
	//NSLog(@"new:%@ dism:%@",message,dismissed);
	if ( message.length > 0 && ! [VMTraumbaumUserDefaults isEqualToLastDismissedMessage:message] ) {
		infoButton.hidden = NO;
		[infoButton setTitle:message forState:UIControlStateNormal];
	} else {
		infoButton.hidden = YES;
	}
	[wholeText release];
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
	[self hideTrackViewIfPresent];
	[UIView animateWithDuration:1.0f
					 animations:^(){
						 self.alpha = 0.;
						 UIView *listView = [self viewWithTag:700];
						 if(listView) {
							 listView.center = CGPointMake( listView.center.x + 320, listView.center.y );
						 }
					 }
					 completion:^(BOOL finished){
						 if( finished ) {
							 [self removeFromSuperview];
						 }
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


- (void)willMoveToSuperview:(UIView *)newSuperview {

	self.backgroundPlaySwitch.on = [VMTraumbaumUserDefaults backgroundPlayback];
	self.backgroundColor = [UIColor colorWithWhite:1. alpha:0.6];	
	[super willMoveToSuperview:newSuperview];
}


- (BOOL)hideTrackViewIfPresent {
	VMPTrackView *tv = (VMPTrackView*)[self viewWithTag:'trkV'];
	if ( tv ) {
		//	hide
		DEFAULTSONGPLAYER.trackView = nil;
		[tv removeFromSuperview];
	}
	return tv != nil;
}

- (void)toggleTrackView:(id)sender {
	if ( supressToggleTrackViewUntil > [NSDate timeIntervalSinceReferenceDate]) return;
	supressToggleTrackViewUntil = [NSDate timeIntervalSinceReferenceDate] + 0.5;
	
	if ( ! [self hideTrackViewIfPresent] ) {
		//	show;
		VMPTrackView *tv = AutoRelease([[VMPTrackView alloc] initWithFrame:self.frame]);
		tv.tag = 'trkV';
		[self addSubview:tv];
		[DEFAULTSONGPLAYER setDimmed:NO];
		DEFAULTSONGPLAYER.trackView = tv;
	}
}

- (void)dealloc {
//	VMNullify(scrollContentView);
	DEFAULTSONGPLAYER.trackView = nil;
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
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.scrollContentView;
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale {
	NSLog(@"End zoom %.2f",scale);
}
*/
@end
