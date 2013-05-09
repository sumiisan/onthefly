//
//  VMDataTypesMacro.h
//  OnTheFly
//
//  Created by  on 13/02/08.
//  Copyright (c) 2013 __MyCompanyName__. All rights reserved.
//

#ifndef OnTheFly_VMDataTypesMacro_h
#define OnTheFly_VMDataTypesMacro_h

#define PropertyDescriptionString(prop,format) \
(self.prop ? [NSString stringWithFormat:format,self.prop] : @"" )

#define VMOBLIGATORY_init(vmObjectType,vmShouldRegister,__code__) \
- (void)initAttributes {\
type_				= vmObjectType;\
shouldRegister_ 	= vmShouldRegister;\
}\
\
- (id)init {\
if ((self = [super init])) {\
[self initAttributes];\
__code__ \
} \
return self;\
}

#define VMOBLIGATORY_initWithProto \
- (id)initWithProto:(id)proto {\
if ((self=[super init] )) [self setWithProto:proto];\
return self;\
}

#define VMOBLIGATORY_setWithProto(__code__) \
- (void)setWithProto:(id)proto {\
[super setWithProto:proto]; \
__code__ \
}

#define VMOBLIGATORY_setWithData(__code__) \
- (void)setWithData:(id)data {\
if ( ClassMatch(data, [self class])) [self setWithProto:data]; \
else {\
[super setWithData:data];\
__code__\
}\
}

#define VMObligatory_resolveUntilType(__code__) \
-(id)resolveUntilType:(int)mask {\
ReturnValueIfNotNil( [self matchMask:mask] );\
__code__ \
return nil; \
}

#define VMObligatory_encodeWithCoder(__code__) \
- (void)encodeWithCoder:(NSCoder *)encoder { \
__code__ \
}

#define VMObligatory_initWithCoder(__code__) \
- (id)initWithCoder:(NSCoder *)decoder { \
if ((self = [super init])) {\
[self initAttributes];\
__code__ \
} \
return self;\
}


#endif
