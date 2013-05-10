//
//  VMPNotification.h
//  OnTheFly
//
//  Created by sumiisan on 2013/05/03.
//
//
#import "MultiPlatform.h"
#import <Foundation/Foundation.h>

#ifndef OnTheFly_VMPNotification_h
#define OnTheFly_VMPNotification_h

#define VMPNotificationCenter [NSNotificationCenter defaultCenter]

//	loading
static NSString *VMPNotificationVMSDataLoaded __unused			= @"VMSDataLoaded";

//	log was added
static NSString *VMPNotificationLogAdded __unused				= @"LogAdded";

//	song player / log

static NSString *VMPNotificationAudioFragmentQueued __unused	= @"AudioFragmentQueued";
static NSString *VMPNotificationAudioFragmentFired  __unused	= @"AudioFragmentFired";

//	score evaluator
static NSString *VMPNotificationVariableValueChanged __unused	= @"VariableValueChanged";

//	editor
static NSString *VMPNotificationFragmentDoubleClicked  __unused	= @"FragmentDoubleClicked";
static NSString *VMPNotificationFragmentSelected __unused		= @"FragmentSelected";

#endif
