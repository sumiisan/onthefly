//
//  VMARC.h
//  OnTheFly
//
//  Created by sumiisan on 2013/05/17.
//
//

#ifndef OnTheFly_VMARC_h
#define OnTheFly_VMARC_h

#define SUPPORT_32BIT_MAC 1

#if __has_feature(objc_arc)


//	ARC
#define AutoRelease(x) (x)				//	[(x) autorelease]
#define Release(x)						//	[(x) release]
#define Retain(x) (x)					//	[(x) retain]
#define Dealloc(x)						//	[x dealloc]
#define VMNullify(x)					//	self.x=nil;
#define VMStrong	strong				//	retain
#define VMReadonly weak,readonly		//	readonly
#define VMWeak weak						//	assign
#define VMUnsafe __unsafe_unretained	//
#define VMBridge __bridge				//	

#else

//	non ARC
#define AutoRelease(x) [(x) autorelease]
#define Release(x) [(x) release]
#define Retain(x) [(x) retain]
#define Dealloc(x) [x dealloc]
#define VMNullify(x) self.x=nil;
#define VMStrong retain
#define VMReadonly readonly
#define VMWeak assign
#define VMUnsafe 
#define VMBridge 

#endif

#endif
