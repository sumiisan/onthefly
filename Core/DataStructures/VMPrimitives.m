//
//  VMPrimitives.m
//  VariableMusicPlayer
//
//  Created by cboy on 12/11/08.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import "VMPrimitives.h"
#import "VMDataTypes.h"
#import "VMException.h"
#include "VMPMacros.h"
#include "boxmuller.h"


VMFloat SNDRand(VMFloat center, VMFloat range) {
	return box_muller(center, range);
}

/*
 limited standard normal distribution random number ( with Sigma = value range / 6 )
 */
VMFloat limitedSNDRand(VMFloat min, VMFloat max) {
	VMFloat range 	= max - min;
	VMFloat s 		= range / 6.;	//	approx where std norm dist falls to zero
	VMFloat m   	= min + (range * .5);
	VMFloat rand  	= box_muller(m, s);
	
	//	limit:
	if( rand < min || rand > max ) rand = limitedSNDRand( min, max );	//recursive
	
	return rand;
}

/*--------------------------------------------

 base class for array and hash
 
 --------------------------------------------*/


@implementation VMArrayBase

- (VMInt)count {
	return 0;	//	virtual
}

- (BOOL)object:(id)obj1 isEqualTo:(id)obj2 {
	if ( obj1 == obj2 ) return YES;
	if ( [obj1 class] != [obj2 class] )return NO;
	
	NSString 	*string = ClassCastIfMatch(obj1, NSString);
	if( string ) 	return [string isEqualToString:obj2];
	
	NSNumber 	*number = ClassCastIfMatch(obj1, NSNumber);
	if ( number ) 	return [number floatValue] == [ClassCast(obj2, NSNumber) floatValue];
	
	VMArray		*array  = ClassCastIfMatch(obj1, VMArray);
	if ( array ) 	return [array allValuesAreEqual:ClassCast(obj2, VMArray)];
	
	VMHash		*hash	= ClassCast(obj1, VMHash);
	if ( hash ) 	return [hash allKeysAndValuesAreEqual:ClassCast(obj2, VMHash)];
	
	VMData 		*data 	= ClassCastIfMatch(obj1, VMData);
	if( data ) 		return [data.id isEqualToString:ClassCast(obj2, VMData).id];
	
	return [obj1 isEqual:obj2];
}

- (NSComparisonResult)object:(id)obj1 compare:(id)obj2 {
	if ( obj1 == obj2 ) return NSOrderedSame;
	if ( [obj1 class] != [obj2 class] )return NSOrderedSame;
	
	NSString 	*string = ClassCastIfMatch(obj1, NSString);
	if( string ) 	return [string compare:ClassCast(obj2,NSString)];
	
	NSNumber 	*number = ClassCastIfMatch(obj1, NSNumber);
	if ( number ) 	return [number compare:ClassCast(obj2, NSNumber)];
	
	VMArray		*array  = ClassCastIfMatch(obj1, VMArray);
	if ( array ) 	return NSOrderedSame;
	
	VMHash		*hash	= ClassCast(obj1, VMHash);
	if ( hash ) 	return NSOrderedSame;
	
	VMData 		*data 	= ClassCastIfMatch(obj1, VMData);
	if( data ) 		return [data.id compare:ClassCast(obj2, VMData).id];
	
	return NSOrderedSame;
}


@end



#pragma mark -
#pragma mark ** Array **


/*--------------------------------------------
 
 array
 
 --------------------------------------------*/
@implementation VMArray

- (id)init {
	self = [super init];
	if( self ) {
		array_ = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc {
	[array_ release];
	[super dealloc];
}

- (void)clear {
	[array_ removeAllObjects];
}

//	NSFastEnumarator
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
	return [array_ countByEnumeratingWithState:state objects:stackbuf count:len];
}

- (NSMutableArray*)array {
	return array_;
}

- (id)initWithArray:(id)arr {
	self = [super init];	
	if( self ) {
		if ( ClassMatch(arr, NSArray)) {
			array_ = [[NSMutableArray alloc] initWithArray:ClassCast(arr, NSArray)];
		} else { //assume VMArray
			array_ = [[NSMutableArray alloc] initWithArray:ClassCast(arr, VMArray).array];
		}
	}
	return self;
}

+ (id)arrayWithArray:(id)arr {
	return [[[VMArray alloc] initWithArray:arr] autorelease];
}

+ (id)arrayWithObject:(id)obj {
	VMArray *a = ARInstance(VMArray);
	[a push:obj];
	return a;
}

+ (id)arrayWithObjects:(id)firstObj, ... {
	VMArray *a = ARInstance(VMArray);
	va_list args;
	id obj;
	if (firstObj) {	// The first argument isn't part of the vararg list
		obj = firstObj;
		va_start(args, firstObj);
		while (obj) {
			[a push:obj];			
			obj = va_arg( args, id );
		}
		va_end(args);
	}
	return a;
}

+ (VMArray*)arrayWithString:(VMString*)string splitBy:(VMString*)separator {
	return [[[VMArray alloc] initWithArray:[string componentsSeparatedByString:separator]] autorelease];
}

+ (id)nullFilledArrayWithSize:(VMInt)size {
	VMArray *a = ARInstance(VMArray);
	while(size--) [a push:nil];		
	return a;
}

- (id)item:(VMInt)pos {
	if( pos < array_.count ) {
		id obj = [array_ objectAtIndex:pos];
		return NilIfNSNull(obj);
	}
	return nil;
}

- (id)lastItem {
	return [self item:[self count]-1];
}

- (VMString*)itemAsString:(VMInt)pos {
	id d = [self item:pos];
	if( ClassMatch(d, NSString)) return d;
	return [d stringValue];	
}

- (VMInt)itemAsInt:(VMInt)pos {
	return [[self item:pos] intValue];	
}

- (VMFloat)itemAsFloat:(VMInt)pos {
	return [[self item:pos] doubleValue];
}

- (id)itemAsObject:(VMInt)pos {
	return [self item:pos];	
}


- (VMHash*)itemAsHash:(VMInt)pos {
	return [self item:pos];
}


- (void)push:(id)obj {
	[array_ addObject:NSNullIfNil(obj)];
}

- (void)pushUnique:(id)obj {
	if( [self position:obj] < 0 ) [self push:obj];
}


- (void)append:(VMArray*)arr {
	[array_	addObjectsFromArray:arr->array_];
}

- (void)appendBefore:(VMArray*)arr {
	VMArray *subArr = [arr copy];
	[subArr append:self];
	[array_ setArray:subArr->array_];
	[subArr release];
}

- (id)pop {
	VMInt idx = [self count]-1;
	id d = [self item:idx];
	[self deleteItem:idx];
	return d;
}

- (void)shift:(id)obj {
	[array_ insertObject:NSNullIfNil(obj) atIndex:0];
}

- (id)unshift {
	id d = [self item:0];
	[self deleteItem:0];
	return d;
}

- (void)setItem:(id)obj at:(VMInt)pos {
	[array_ replaceObjectAtIndex:pos withObject:NSNullIfNil(obj)];
}


- (void)deleteItemsFrom:(VMInt)fromPosition to:(VMInt)toPosition {
	if ( fromPosition >= self.count ) return;
	if ( toPosition   <  fromPosition ) toPosition = self.count -1;
	NSRange range = { fromPosition, toPosition - fromPosition +1 };
	[array_ removeObjectsInRange:range];
}

- (void)crop:(VMRange)itemsToLeave {
	[array_ setArray:[array_ subarrayWithRange:
					  NSMakeRange((int) itemsToLeave.minimum,
								  (int) itemsToLeave.maximum - itemsToLeave.minimum )]];
}


- (void)truncateFirst:(VMInt)numberOfDataToLeave {
	VMInt numberOfDataToThrowAway = self.count - numberOfDataToLeave;
	if ( numberOfDataToThrowAway > 0 ) {
		NSRange range = { 0, numberOfDataToThrowAway };
		[array_ removeObjectsInRange:range];
	}
}

- (void)truncateLast:(VMInt)numberOfDataToLeave {
	VMInt numberOfDataToThrowAway = self.count - numberOfDataToLeave;
	if ( numberOfDataToThrowAway > 0 ) {
		NSRange range = { self.count - numberOfDataToThrowAway, numberOfDataToThrowAway };
		[array_ removeObjectsInRange:range];
	}
}

- (VMInt)count {
	return (VMInt)[array_ count];
}

- (VMInt)position:(id)val {
	NSUInteger index;
	Class valClass = [val class];
	if (ClassMatch(val, NSString)) {
		index 
		= [array_ indexOfObjectPassingTest:
		   ^BOOL(id obj, NSUInteger idx, BOOL *stop) {
			   if( [obj isKindOfClass:[NSString class]] && [(NSString*)obj isEqualToString:(NSString *)val ] ) {
				   *stop = YES;
				   return YES;
			   };
			   return NO;
		   }];
	} else if ( ClassMatch(val, VMData) ) {
		VMId *vid = [ClassCast(val, VMData) id];
		index 
		= [array_ indexOfObjectPassingTest:
		   ^BOOL(id obj, NSUInteger idx, BOOL *stop) {
			   if ([obj class] == valClass
				   && ClassMatch(obj, VMData)
				   && [ClassCast(obj, VMData).id isEqualToString: vid] ) {
				   *stop = YES;
				   return YES;
			   };
			   return NO;
		   }];
	} else if ( ClassMatch(val, VMHash) ) {
		index 
		= [array_ indexOfObjectPassingTest:
		   ^BOOL(id obj, NSUInteger idx, BOOL *stop) {
			   if ([obj class] == valClass && [self object:val isEqualTo:obj] ) {
				   *stop = YES;
				   return YES;
			   }
			   return NO;
		   }];
	} else {
		index = [array_ indexOfObject:val];
	}
	
	if ( index == NSNotFound ) return -1;
	return (int)index;
}

- (BOOL)hasItem:(id)val {
	return( [self position:val] >= 0 );
}

- (void)deleteItem:(VMInt)pos {
	if ( array_.count > pos ) [array_ removeObjectAtIndex:pos];
}



- (void)insert:(id)obj at:(VMInt)pos {
	[array_ insertObject:obj atIndex:pos];
}

- (void)insertArray:(id)obj at:(VMInt)pos {
	VMArray *arr = ConvertToVMArray(obj);
	for( id member in arr )
		[self insert:member at:pos++];
}


- (void)deleteItemWithValue:(id)val {
	VMInt p=[self position:val];
	if( p  >= 0 )
		[array_ removeObjectAtIndex:p];
}

- (VMString*)join:(NSString*)glue {
	return [array_ componentsJoinedByString:glue];
}

- (void)swapItem:(VMInt)p withItem:(VMInt)q {
	[array_ exchangeObjectAtIndex:p withObjectAtIndex:q];
}

- (void)reverse {
    if ([self count] == 0) return;
    VMInt i = 0;
    VMInt j = [self count] - 1;
    while (i < j)
        [self swapItem:i++ withItem:j--];
}

- (BOOL)allValuesAreEqual:(VMArray*)anArray {
	VMInt c = [self count];
	if( c != [anArray count] ) return NO;
	for( VMInt i = 0; i < c; ++i )
		if (![self object:[self item:i] isEqualTo:[anArray item:i]]) return NO;
			  
	return YES;
}

//
- (void)sort:(VMSortDirection)direction {
	switch (direction) {
		case VMSortDirection_ascending:
			[array_ sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
				return [self object:obj1 compare:obj2];
			}];
			break;
		case VMSortDirection_descending:
			[array_ sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
				return [self object:obj2 compare:obj1];
			}];
			break;
	}
}



//	statistics
- (VMFloat)sum {
	VMFloat s = 0;
	for (id val in array_ ) {
		s += [val floatValue];
	}
	return s;
}

- (VMRange)valueRange {
	VMFloat min = INT64_MAX;
	VMFloat max = 0;
	for ( NSNumber *v in array_ ) {
		VMFloat f = v.floatValue;
		if ( f > max ) max = f;
		if ( f < min ) min = f;
	}
	return VMRangeMake( min, max );
}

- (VMFloat)mean {
	return [self sum] / self.count;	
}

- (VMFloat)median {
	VMArray *tempArray = [self copy];
	[tempArray sort:VMSortDirection_ascending];
	VMFloat median = [tempArray itemAsFloat:tempArray.count / 2];
	[tempArray release];
	return median;
}

- (VMFloat)variance {
	double mean = 0.;
	double sum	= 0.;
	int k = 1;

	for ( id d in array_ ) {
		VMFloat v = [d doubleValue];
		double tm = mean;
		mean	+= ( v - tm ) / k;
		sum 	+= ( v - tm ) * ( v - mean );
		++k;
	}
	return sum / ( k > 1 ? k-1 : k );
}

- (VMFloat)standardDeviation {
	return sqrt([self variance]);
}

- (VMArray*)histogramWithBins:(VMInt)numberOfBins
					normalize:(BOOL)normalize {
	VMRange range = [self valueRange];
	VMFloat interval = ( range.maximum - range.minimum ) / (VMFloat)( numberOfBins -1 );
	VMInt	maxCount = 0;
	VMArray *tempArray = ARInstance(VMArray);
	for ( int i = 0; i < numberOfBins; ++i ) [tempArray push:VMIntObj(0)];
	for ( NSNumber *num in array_ ) {
		int bin = ( interval ? (([num floatValue] - range.minimum ) / interval ) : 0 );
		VMInt c = [tempArray itemAsInt:bin];
		++c;
		if ( c > maxCount ) maxCount = c;
		[tempArray setItem:VMIntObj(c) at:bin];
	}
	
	if ( normalize && maxCount > 0 ) {
		VMInt c = tempArray.count;
		for ( int bin = 0; bin < c; ++bin ) {
			[tempArray setItem:VMFloatObj([tempArray itemAsFloat:bin] / maxCount) at:bin];
		}
	}
	return tempArray;
}


- (NSString*)description {
	return [NSString stringWithFormat:@"(%@)", [self join:@", "]];	
}

//	NSCoding
- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:array_ forKey:@"array"];
}

//
- (id)initWithCoder:(NSCoder *)aDecoder {
	if((self=[super init])) {
		array_ = [[aDecoder decodeObjectForKey:@"array"] retain];
	}
	return self;
}


//	NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return [[VMArray allocWithZone:zone] initWithArray:self];
}

@end

#pragma mark -
#pragma mark ** Stack **

@implementation VMStack

- (id)current {
	return NilIfNSNull([array_ lastObject]);
}

- (void)setCurrent:(id)current {
	[array_ addObject:NSNullIfNil(current)];
}

- (void)restore {
	[array_ removeLastObject];
}


@end

#pragma mark -
#pragma mark ** Hash **

/*--------------------------------------------
 
 	hash
 
 --------------------------------------------*/

@implementation VMHash

- (id)init {
	if((self=[super init])) {
		hash_ = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (NSDictionary*)hash {
	return hash_;
}

+ (id)hashWithObjectsAndKeys:(id)firstObject, ... {
	VMHash *h = ARInstance(VMHash);
	va_list args;
	id obj;
	VMHashKeyType key;
	if (firstObject) {	// The first argument isn't part of the vararg list
		obj = firstObject;
		va_start(args, firstObject);
		while (obj) {
			key = va_arg( args, VMHashKeyType );
			[h setItem:obj for:key];			
			obj = va_arg( args, id );
		}
		va_end(args);
	}
	return h;
}

- (id)initWithHash:(id)dict {
	if((self=[super init])) {
		if( ClassMatch(dict, NSDictionary)) {
			hash_ = [[NSMutableDictionary alloc] initWithDictionary:ClassCast(dict, NSDictionary)];
		} else {
			hash_ = [[NSMutableDictionary alloc] initWithDictionary:ClassCast(dict, VMHash).hash];
		}
	}
	return self;
}

+ (id)hashWith:(NSDictionary*)dict {
	return [[[VMHash alloc] initWithHash:dict] autorelease];
}

+ (id)hashWithDictionary:(id)dict {
	return [[[VMHash alloc] initWithHash:dict] autorelease];
}

- (void)renameKey:(VMHashKeyType)oldKey to:(VMHashKeyType)newKey {
	id obj = [self item:oldKey];
	if ( ! obj ) {
		[VMException raise:@"Key doesn't exist" 
					format:@"Key %@ not found in VMHash", oldKey];
		return;
	}
	if ( [hash_ objectForKey:newKey] ) {
		[VMException raise:@"Key already exist" format:@"Cannot overwrite key %@ in VMHash", newKey];
		return;
	}
	[self setItem:obj for:newKey];
	[self removeItem:oldKey];
}


- (BOOL)allKeysAndValuesAreEqual:(VMHash*)aHash {
	if ( [self count] != [aHash count] ) return NO;
	VMArray *keys = [self keys];
	for( VMHashKeyType key in keys ) {
		if (! [self object:[self item:key] isEqualTo:[aHash item:key]] ) return NO;
	}
	return YES;
}


- (void)dealloc {
	[hash_ release];
	[super dealloc];
}

- (id)item:(VMHashKeyType)key {
	id it = [hash_ objectForKey:key];
	return NilIfNSNull(it);
}

- (VMHash*)itemAsHash:(VMHashKeyType)key {
	id it = [hash_ objectForKey:key];
	return NilIfNSNull(it);
}


- (NSString*)itemAsString:(VMHashKeyType)key {
	id d = [self item:key];
	if( ClassMatch(d, NSString)) return d;
	return [d stringValue];	
}

- (int)itemAsInt:(VMHashKeyType)key {
	return [[self item:key] intValue];	
}

- (VMFloat)itemAsFloat:(VMHashKeyType)key {
	return [[self item:key] doubleValue];	
}

- (id)itemAsObject:(VMHashKeyType)key {
	return [self item:key];	
}


- (void)setItem:(id)obj for:(VMHashKeyType)key {
	[hash_ setObject:NSNullIfNil(obj)  forKey:key];
}

- (void)removeItem:(VMHashKeyType)key {
	[hash_ removeObjectForKey:key];
}

- (void)clear {
	[hash_ removeAllObjects];
}

- (void)push:(id)obj intoArrayItem:(VMHashKeyType)key {
	VMArray *arr = [self item:key];
	if ( !arr ) {
		arr = ARInstance(VMArray);
		[self setItem:arr for:key];
	}
	if (!ClassMatch(arr, VMArray)) [VMException raise:@"Type mismatch" format:@"Can't push %@ into item %@ of VMHash", obj, key];
	[arr push:obj];
}

- (void)add:(VMFloat)value ontoItem:(VMHashKeyType)key {
	NSNumber *num = [self item:key];
	if ( !num ) 
		num = [NSNumber numberWithDouble:0];
	else
		if (!ClassMatch(num, NSNumber))
			[VMException raise:@"Type mismatch" format:@"Can't add %f onto item %@ of VMHash", value, key];
	
	num = [NSNumber numberWithDouble:[num doubleValue] + value];
	[self setItem:num for:key];
	
}

- (void)merge:(VMHash*)aHash {
	[hash_ addEntriesFromDictionary:aHash.hash];
}

- (void)deepMerge:(VMHash*)aHash {
	VMArray *keys = [aHash keys];	
	for( VMString *key in keys ) {
		id obj1 = [self item:key];
		id obj2 = [aHash item:key];
		if ( ! obj2 ) continue;
		if ( ! obj1 ) {
			[self setItem:obj2 for:key];
		} else {
			//	merge if one of objects is an array.
			if ( ClassMatch( obj1, VMArray )) {
				if ( ClassMatch( obj2, VMArray )) 
					[(VMArray*)obj1 append:(VMArray*)obj2];
				else 
					[(VMArray*)obj1 push:obj2];
			} else if ( ClassMatch( obj2, VMArray )) {
				VMArray *cpy = [[obj2 copy] autorelease];
				[cpy shift:obj1];
				obj1 = cpy;
				[self setItem:obj1 for:key];
			} else if ( ![obj1 isKindOfClass:[obj2 class]] ) {
				[VMException raise:@"Type mismatch." format:@"Cannot deep-merge key %@ in VMHash", key];
				return;
			}
			if ( ClassMatch( obj1, VMHash ) ) {
				[(VMHash*)obj1 deepMerge:(VMHash*)obj2];	//	recursive  
			} else {
				//	make a new array!
				[self setItem:[VMArray arrayWithObjects: obj1, obj2, nil ] 
						  for:key];
			}
		}
		
	}
	
}


- (VMInt)count {
	return (VMInt)[hash_ count];
}

- (VMArray*)keys {
	return [VMArray arrayWithArray:[hash_ allKeys]];	
}

- (VMArray*)values {
	return [VMArray arrayWithArray:[hash_ allValues]];
}

- (VMArray*)sortedKeys {
	NSArray *keys = [hash_ allKeys];
	NSArray *skeys = [keys sortedArrayUsingComparator:^(id obj1, id obj2) {
		//	there is a potential BUG which sets VMArray as key.	i couldn't solve. ss121211
		if( ClassMatch(obj1, VMArray) || ClassMatch(obj2, VMArray) )
			[VMException raise:@"array was set as key" format:@"%@",self.description];
		return [(NSString *)obj1 compare:(NSString *)obj2];
	}];
	return [VMArray arrayWithArray:skeys];
}

- (VMArray*)keysSortedByValue {
	NSArray *keys = [hash_ keysSortedByValueUsingComparator:^NSComparisonResult(id obj1, id obj2) {
		return [self object:obj1 compare:obj2];
	}];
	return [VMArray arrayWithArray:keys];
}

- (NSString*)description {
	VMArray *lines = NewInstance(VMArray);
	VMArray *keys = [self sortedKeys];
	for (NSString *key in keys ) {
		id val = [self item:key];
		if( ClassMatch(val, VMHash) || ClassMatch(val, VMArray )) val = [val description];
		[lines push:[NSString stringWithFormat:@"%@=%@",key,val]];
	}
	NSString *desc = [NSString stringWithFormat:@"{ %@ }",[lines join:@",\n"]];
	[lines release];
	return desc;
}


//	NSCoding
- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:hash_ forKey:@"hash"];
}

//
- (id)initWithCoder:(NSCoder *)aDecoder {
	if((self=[super init])) {
		hash_ = [[aDecoder decodeObjectForKey:@"hash"] retain];
	}
	return self;
}


//	NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return [[VMHash allocWithZone:zone] initWithHash:self];
}




@end


#pragma mark -
#pragma mark ** Hashed Array **

/*---------------------------------------------------------------------------------
 *
 *
 *	VM Hashed Array ( array with uncontinuous index )
 *
 *
 *---------------------------------------------------------------------------------*/


@implementation VMHashedArray

#define VMHashedArraySetLastIndex \
if ( lastIndex == 0 ) {\
	[self setKeys];\
	lastIndex = [[keys_ lastObject] intValue];\
}

- (id)init {
	self = [super init];
	keysUpToDate = NO;
	lastIndex = 0;
	values_ = [[NSMutableDictionary alloc] init];
	return self;
}

- (id)initWithValues:(id)values {
	self = [super init];
	if (self) {
		if (ClassMatch(values, VMArray)) values = ((VMArray*)values).array;
		if (ClassMatch(values, VMHash )) values = ((VMHash*) values).hash;
		
		if (ClassMatch(values, NSArray)) {
			values_ = [[NSMutableDictionary alloc] init];
			[self setArray:values fromIndex:0];
		}
		if (ClassMatch(values, NSDictionary))
			values_ = [((NSDictionary*)values) mutableCopy];	//retained
		
		VMHashedArraySetLastIndex;
	}
	return self;
}

- (VMInt)count {
	return values_.count;
}

- (void)setKeys {//internal
	if (keysUpToDate) return;
	NSArray *unsortedKeys = [values_ allKeys];
	[keys_ release];
	keys_ = [[unsortedKeys sortedArrayUsingComparator:^(id obj1, id obj2) {
		//	there is a potential BUG which sets VMArray as key.	i couldn't solve. ss121211
		if( ClassMatch(obj1, VMArray) || ClassMatch(obj2, VMArray) )
			[VMException raise:@"array was set as key" format:@"%@",self.description];
		return [(NSString *)obj1 compare:(NSString *)obj2];
	}] mutableCopy];
	keysUpToDate = YES;
}

//	position
- (BOOL)hasItem:(id)val {
	return [self position:val] >= 0;
}

- (VMInt)position:(id)val {
	__block NSInteger index = -1;	
	[values_ enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		if ( [self object:obj isEqualTo:val]) {
			index = [key integerValue];
			*stop = YES;
		}
	}];
	return index;
}

//	get
- (id)item:(VMInt)pos {
	return NilIfNSNull( [values_ objectForKey:VMIntObj(pos)] );
}

- (id)lastItem {
	VMHashedArraySetLastIndex;
	return [self item:lastIndex];
}
						 
- (VMString*)itemAsString:(VMInt)pos {
	return NilIfNSNull( [values_ objectForKey:VMIntObj(pos)]);
}
						 
- (VMInt)itemAsInt:(VMInt)pos {
	return [[values_ objectForKey:VMIntObj(pos)] intValue];
}

- (VMFloat)itemAsFloat:(VMInt)pos {
	return [[values_ objectForKey:VMIntObj(pos)] floatValue];
}

- (id)itemAsObject:(VMInt)pos {
	return NilIfNSNull( [values_ objectForKey:VMIntObj(pos)]);
}

//	set
- (void)setItem:(id)obj at:(VMInt)pos {
	[values_ setObject:obj forKey:VMIntObj(pos)];
	if ( pos > lastIndex ) lastIndex = pos;
	keysUpToDate = NO;
}


//	push, pop, shift and unshift
- (void)push:(id)obj {
	VMHashedArraySetLastIndex;
	++lastIndex;
	[values_ setObject:obj forKey:VMIntObj(lastIndex)];
	[keys_ addObject:obj];
}
- (id)pop {
	VMHashedArraySetLastIndex;
	id result = [values_ objectForKey:VMIntObj(lastIndex)];
	[values_ removeObjectForKey:VMIntObj(lastIndex)];
	lastIndex = 0;
	[keys_ removeLastObject];
	return result;
}

//	delete
- (void)deleteItem:(VMInt)pos {
	[values_ removeObjectForKey:VMIntObj(lastIndex)];
	keysUpToDate = NO;
	if ( pos == lastIndex ) lastIndex = 0;
}

- (void)clear {
	[values_ removeAllObjects];
	[keys_ removeAllObjects];
	keysUpToDate = NO;
	lastIndex = 0;
}

- (void)setArray:(id)array fromIndex:(VMInt)startIndex {
	NSArray *arr = ( ClassMatch(VMArray, array) ? ((VMArray*)array).array : array );
	VMInt p = 0;
	VMInt index = startIndex;
	for (id val in arr )
		[self setItem:[arr objectAtIndex:p++] at:index++];
	keysUpToDate = NO;
	lastIndex = 0;
}

- (void)deleteItemsExcludingRange:(NSRange)range {
	[self setKeys];
	VMInt start = range.location;
	VMInt end   = range.location + range.length;
	VMInt c		= keys_.count;
	VMInt ki	= 0;
	for( ; ki < c; ++ki ) {
		//	delete while index < start
		NSNumber *index = [keys_ objectAtIndex:ki];
		if ( index.intValue < start )
			[values_ removeObjectForKey:index];
		else
			break;
	}

	for( ; ki < c; ++ki ) {
		//	skip indexes in range
		NSNumber *index = [keys_ objectAtIndex:ki];
		if ( index.intValue >= end ) break;
	}

	for( ; ki < c; ++ki ) {
		//	delete until end
		NSNumber *index = [keys_ objectAtIndex:ki];
			[values_ removeObjectForKey:index];
	}

	keysUpToDate = NO;
	lastIndex = 0;
}

- (void)truncateFirst:(VMInt)numberOfDataToLeave {
	
}

//	NSFastEnumarator
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
	NSUInteger count = 0;
	if(state->state == 0) {
		//	init
		[self setKeys];
		state->mutationsPtr = &keysUpToDate;
	}
	if(state->state < values_.count ) {
        // Set state->itemsPtr to the provided buffer.
        state->itemsPtr = stackbuf;
        // Fill in the stack array, either until we've provided all items from the list
        while(( state->state < values_.count ) && (count < len )) {
            stackbuf[count] = [values_ objectForKey:[keys_ objectAtIndex:state->state]];
            state->state++;
            count++;
        }
    } else {
		count = 0;
	}

	return count;
}

- (void)dealloc {
	[values_ release];
	[keys_ release];
	[super dealloc];
}

//	NSCoding, NSCopying
- (void)encodeWithCoder:(NSCoder *)aCoder {
	[aCoder encodeObject:values_ forKey:@"hash"];
}

//
- (id)initWithCoder:(NSCoder *)aDecoder {
	if((self=[super init])) {
		values_ = [[aDecoder decodeObjectForKey:@"hash"] retain];
		VMHashedArraySetLastIndex;
	}
	return self;
}


//	NSCopying

- (id)copyWithZone:(NSZone *)zone {
	return [[VMHashedArray allocWithZone:zone] initWithValues:values_];
}


@end
