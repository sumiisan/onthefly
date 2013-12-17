//
//  VMPTwitter.m
//  OnTheFly
//
//  Created by sumiisan on 2013/11/27.
//
//

// SCSimpleSLRequestDemo.m
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "VMPTwitter.h"



@interface VMPTwitter()
@property (nonatomic,retain) ACAccountStore *accountStore;
@end

@implementation VMPTwitter
@synthesize timelineData=timelineData_;
@synthesize accountStore=accountStore_;

- (id)init {
	self = [super init];
	if (self) {
		accountStore_ = [[ACAccountStore alloc] init];
	}
	return self;
}

- (void)dealloc {
	self.accountStore = nil;
	self.timelineData = nil;
	[super dealloc];
}

- (BOOL)userHasAccessToTwitter {
	return [SLComposeViewController
			isAvailableForServiceType:SLServiceTypeTwitter];
}

- (void)fetchTLforUser:(NSString *)username language:(VMPLanguageCode)languageCode {	
	//  Step 1:  Obtain access to the user's Twitter accounts
	ACAccountType *twitterAccountType =
	[self.accountStore accountTypeWithAccountTypeIdentifier:
	 ACAccountTypeIdentifierTwitter];
	
	[self.accountStore
	 requestAccessToAccountsWithType:twitterAccountType
	 options:NULL
	 completion:^(BOOL granted, NSError *error) {
		 if (granted) {
			 //  Step 2:  Create a request
			 NSArray *twitterAccounts =
			 [self.accountStore accountsWithAccountType:twitterAccountType];
			 NSURL *url = [NSURL URLWithString:@"https://api.twitter.com"
						   @"/1.1/statuses/user_timeline.json"];
			 NSDictionary *params = @{@"screen_name" : username,
									  @"include_rts" : @"0",
									  @"trim_user" : @"1",
									  @"count" : @"5"};
			 SLRequest *request =
			 [SLRequest requestForServiceType:SLServiceTypeTwitter
								requestMethod:SLRequestMethodGET
										  URL:url
								   parameters:params];
			 
			 //  Attach an account to the request
			 [request setAccount:[twitterAccounts lastObject]];
			 
			 //  Step 3:  Execute the request
			 [request performRequestWithHandler:
			  ^(NSData *responseData,
				NSHTTPURLResponse *urlResponse,
				NSError *error2) {
				  
				  if (responseData) {
					  if (urlResponse.statusCode >= 200 &&
						  urlResponse.statusCode < 300) {
						  
						  NSError *jsonError;
						  self.timelineData =
						  [NSJSONSerialization
						   JSONObjectWithData:responseData
						   options:NSJSONReadingAllowFragments error:&jsonError];
						  if (self.timelineData) {
							  NSLog(@"Timeline Response: %@\n", self.timelineData);
							  [[NSNotificationCenter defaultCenter] postNotificationName:TWITTERTIMELINEFETCHED_NOTIFICATION
																				  object:self
																				userInfo:self.timelineData];
						  }
						  else {
							  // Our JSON deserialization went awry
							  NSLog(@"JSON Error: %@", [jsonError localizedDescription]);
						  }
					  }
					  else {
						  // The server did not respond ... were we rate-limited?
						  NSLog(@"The response status code is %d",
								urlResponse.statusCode);
					  }
				  }
			  }];
		 }
		 else {
			 // Access was not granted, or an error occurred
			 NSLog(@"%@", [error localizedDescription]);
		 }
	 }];
}

@end
