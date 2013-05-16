//
//  VMPMacros.h
//  VariableMusicPlayer
//
//  Created by  on 12/11/24.
//  Copyright (c) 2012 sumiisan (aframasda.com). All rights reserved.
//

#ifndef OnTheFly_VMPreprocessorMacros_h
#define OnTheFly_VMPreprocessorMacros_h

//	primitives
//#define Default(expr,default) ((expr)?(expr):(default))
#define Default(expr,default) ({ __typeof__( expr ) tmp_ = (expr); tmp_ ? tmp_ : (default); })
#define SMAX(A,B)	( (A) < (B) ? (B) : (A) )	// just a simple max function allowing us nesting without warings.
#define SMIN(A,B)	( (A) > (B) ? (B) : (A) )	// just a simple min function allowing us nesting without warings.

//	c language related
#define until(expression) while(!(expression))
#define doForever for(;;)

//	log
#ifdef DEBUG
	#define LLog(fmt,...)			NSLog(fmt,##__VA_ARGS__)
	#define VerboseLog(fmt,...) 	if(verbose)NSLog(fmt,##__VA_ARGS__)
#else
	#define LLog(...)
	#define VerboseLog(...)
#endif
#define Warning(type,detail)	NSLog(@"[%@] %@ at %s",type,detail,__PRETTY_FUNCTION__)

//	benchmark
#define MakeTimestamp(name) NSTimeInterval name = [NSDate timeIntervalSinceReferenceDate];
#define LogTimeBetweenTimestamps(ts1,ts2) NSLog( @"Time(%@ - %@): %.3fsec", @"" #ts1, @"" #ts2, fabs( ts2 - ts1 ));


//	alloc instances
#define NewInstance(cls) [[cls alloc]init]
#define ARInstance(cls) [NewInstance(cls) autorelease]
#define NewInstanceIfNil(var,cls) if(!var)var=NewInstance(cls)
#define ReleaseAndNewInstance(var,cls) [var release];var=NewInstance(cls)
#define ReleaseAndNil(var) [var release];var=nil

//	class macro
#define ClassMatch(var,cls) [var isKindOfClass:[cls class]]
#define ExactClassMatch(var,cls) [var isMemberOfClass:[cls class]]
#define ClassCast(var,cls) ((cls*)var)
#define MakeVarByCast(newVar,fromVar,cls) cls *newVar=ClassCast(fromVar, cls);
#define ClassCastIfMatch(var,cls) (ClassMatch(var,cls)?ClassCast(var,cls):nil)


//	selector
#define HasMethod(instance,method) ([instance respondsToSelector:@selector(method)])

//	NSNumber
#define VMIntObj(x) 		[NSNumber numberWithLong:(x)]
#define VMFloatObj(x) 		[NSNumber numberWithDouble:(x)]
#define VMBoolObj(x)		[NSNumber numberWithBool:(x)]

#define AsVMInt(x)		[x intValue]
#define AsVMFloatObj(x)	[x floatValue]
#define AsVMBool(x)		[x boolValue]

//	the 'pittari-ping-pong' (perfect-fit) macro. (macro name invented by my daughter)
#define Pittari(dynObj,statObj) ((ClassMatch((statObj),VMString))?[((NSString*)(statObj)) isEqualToString:((NSString*)(dynObj))]\
								:(ClassMatch((statObj),NSNumber)?[((NSNumber*)(statObj)) isEqualToNumber:((NSNumber*)(dynObj))]\
								:(((id)dynObj)==((id)statObj))))

//	string
#define EmptyStringIfNull(val) Default(val,@"")

//	array
#define ReadAsVMArray(obj) (VMArray*)(ClassMatch(obj,NSArray)?[VMArray arrayWithArray:obj]:(ClassMatch(obj,VMArray)?ClassCast(obj,VMArray):nil))
#define ReadAsVMHash(obj) (VMHash*)(ClassMatch(obj,NSDictionary)?[VMHash hashWithDictionary:obj]:(ClassMatch(obj,VMHash)?ClassCast(obj,VMHash):nil))

#define ConvertToVMArray(val)	(VMArray*)(ClassMatch(val,VMArray)?ClassCast(val,VMArray):\
									(ClassMatch(val,NSArray)?[VMArray arrayWithArray:val]:\
										(val?[VMArray arrayWithObject:val]:nil)\
									)\
								)
#define VMArrayToList2(arr,item1,item2) {VMArray*tempArr=arr;item1=[tempArr item:0];item2=[tempArr item:1];}
#define VMArrayToList3(arr,item1,item2,item3) {VMArray*tempArr=arr;item1=[tempArr item:0];item2=[tempArr item:1];item3=[tempArr item:3];}

//	hash macro			 
#define MakeHashFromData MakeVarByCast(hash,data,VMHash);

//#define ItemInHash(key,hash) [hash item:@"" #key]
//#define SetItemInHash(key,hash,val) [hash setItem:val for:@"" #key]

//	direct access to NSMutableDictionary
#define ItemInHash(key,hash) [hash->hash_ objectForKey:@"" #key]
#define SetItemInHash(key,hash,val) [hash->hash_ setObject:val forKey:@"" #key]

#define HashItem(key) ItemInHash(key,hash)
#define IfHashItemExist(key,__code__) {\
id HASHITEM=HashItem(key); \
if(HASHITEM) { __code__ ;}}
#define SetHashItem(key,val) SetItemInHash(key,hash,(val))
#define CopyHashItem(key,fromHash,toHash) {id tempValue=[fromHash item:@"" #key]; if(tempValue) [toHash setItem:tempValue for:@"" #key];}

//	do [prop setWithData] if key exist in dictionary
#define SetDataIfKeyExist(prop,key,type) IfHashItemExist(key,\
if (!self->prop) self.prop=ARInstance(type);\
[self.prop setWithData:HASHITEM];)

//	set property from dictionary
#define SetPropertyIfKeyExist(key,valueType) if(HashItem(key)){self.key=[hash valueType:@"" #key];}

//	copy property from proto
#define CopyPropertyIfExist(key) if(HasMethod(proto,key)) self.key =[proto key];



//	set struct member in property
#define SetStructMemberInProp(propName,structMember,structType,value){ \
structType structVal = self.propName;\
structVal.structMember=value;\
self.propName=structVal;}

//	serialize
#define Serialize(prop,typ) [encoder encode##typ:self.prop forKey:@"" #prop];
#define Deserialize(prop,typ) self.prop=[decoder decode##typ##ForKey: @"" #prop];

//	read as VMId
#define ReadAsVMId(obj) (ClassMatch(obj,NSString)?ClassCast(obj,NSString):\
(ClassMatch(obj,VMHash)?[ClassCast(obj, VMHash) item:@"id"]:\
(ClassMatch(obj,VMData)?ClassCast(obj,VMData).id:nil)))

//	property redirection
#define RedirectPropGetterToObject(cls,prop,obj) \
- (cls)prop{return obj.prop;}
#define RedirectPropSetterToObject(cls,setterName,prop,obj) \
- (void)setterName:(cls)value {obj.prop=value;}

//	nil
#define ReturnValueIfNotNil(value) {id tempValue=(value); if(tempValue) return tempValue;}
#define NSNullIfNil(obj) (( obj ) ?  obj : [NSNull null] )
#define NilIfNSNull(obj) (( obj == [NSNull null] ) ? nil : obj )


#endif
