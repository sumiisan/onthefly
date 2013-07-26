//
//  VMDataTypesMacro.h
//  OnTheFly
//
//  Created by  on 13/02/08.
//  Copyright (c) 2013 sumiisan. All rights reserved.
//

//
//	macros for defining obligatory functions
//

#ifndef OnTheFly_VMDataTypesMacro_h
#define OnTheFly_VMDataTypesMacro_h

#define PropertyDescriptionString(prop,format) \
(self.prop ? [NSString stringWithFormat:format,self.prop] : @"" )

#define VMOBLIGATORY_init(vmObjectType,vmShouldRegister,_code_) \
- (void)initAttributes {\
type_				= vmObjectType;\
shouldRegister_ 	= vmShouldRegister;\
}\
\
- (id)init {\
if ((self = [super init])) {\
[self initAttributes];\
_code_ \
} \
return self;\
}

#define VMOBLIGATORY_initWithProto \
- (id)initWithProto:(id)proto {\
if ((self=[super init] )) [self setWithProto:proto];\
return self;\
}

#define VMOBLIGATORY_setWithProto(_code_) \
- (void)setWithProto:(id)proto {\
[super setWithProto:proto]; \
_code_ \
}

#define VMOBLIGATORY_setWithData(_code_) \
- (void)setWithData:(id)data {\
if ( ClassMatch(data, [self class])) [self setWithProto:data]; \
else {\
[super setWithData:data];\
_code_\
}\
}

#define VMObligatory_containsId(_code_) \
- (BOOL)containsId:(VMId *)dataId {\
	if ( [self.id isEqualToString:dataId] ) return YES;\
	_code_ \
	return NO;\
}



#define VMObligatory_resolveUntilType(_code_) \
-(id)resolveUntilType:(int)mask {\
ReturnValueIfNotNil( [self matchMask:mask] );\
_code_ \
return nil; \
}

#define VMObligatory_encodeWithCoder(_code_) \
- (void)encodeWithCoder:(NSCoder *)encoder { \
_code_ \
[super encodeWithCoder:encoder];\
}

#define VMObligatory_initWithCoder(_code_) \
- (id)initWithCoder:(NSCoder *)decoder { \
if ((self = [super init])) {\
[self initAttributes];\
[super initWithCoder:decoder];\
_code_ \
} \
return self;\
}


#endif
