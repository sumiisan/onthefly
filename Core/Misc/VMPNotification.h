//
//  VMPNotification.h
//  OnTheFly
//
//  Created by sumiisan on 2013/05/03.
//
//
#ifndef OnTheFly_VMPNotification_h
#define OnTheFly_VMPNotification_h

#define VMPNotificationCenter [NSNotificationCenter defaultCenter]

//	loading
static NSString *VMPNotificationVMSDataLoaded __unused			= @"VMSDataLoaded";

//	log
static NSString *VMPNotificationLogAdded __unused				= @"LogAdded";

//	song

//	song player
static NSString *VMPNotificationAudioFragmentQueued __unused	= @"AudioFragmentQueued";
static NSString *VMPNotificationAudioFragmentFired  __unused	= @"AudioFragmentFired";
static NSString *VMPNotificationStartChaseSequence __unused		= @"StartChaseSequence";

//	score evaluator
static NSString *VMPNotificationVariableValueChanged __unused	= @"VariableValueChanged";

//	editor and various windows
static NSString *VMPNotificationFragmentDoubleClicked  __unused	= @"FragmentDoubleClicked";
static NSString *VMPNotificationFragmentSelected __unused		= @"FragmentSelected";

#endif
