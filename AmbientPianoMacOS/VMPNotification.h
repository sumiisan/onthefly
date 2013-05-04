//
//  VMPNotification.h
//  GotchaP
//
//  Created by sumiisan on 2013/05/03.
//
//
#import "MultiPlatform.h"
#import <Foundation/Foundation.h>

#ifndef GotchaP_VMPNotification_h
#define GotchaP_VMPNotification_h

#define VMPNotificationCenter [NSNotificationCenter defaultCenter]

//	song player / log

static NSString *VMPNotificationAudioCueQueued __unused			= @"AudioCueQueued";
static NSString *VMPNotificationAudioCueFired  __unused			= @"AudioCueFired";

//	score evaluator
static NSString *VMPNotificationVariableValueChanged __unused	= @"VariableValueChanged";


//	editor
static NSString *VMPNotificationCueDoubleClicked  __unused		= @"CueDoubleClicked";
static NSString *VMPNotificationCueSelected __unused			= @"CueSelected";

#endif
