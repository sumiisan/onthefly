//
//  VMPrimitives_h.h
//  VariableMusicPlayer
//
//  Created by cboy on 12/11/08.
//  Copyright 2012 sumiisan (aframasda.com). All rights reserved.
//

#import <Foundation/Foundation.h>
#include <stdlib.h>
#import "VMARC.h"


//	make properties nonatomic on iOS devices.	//	implicit and can be thread unsafe. : remove in future
#if TARGET_OS_IPHONE
#define VMNonatomic	nonatomic,
#else
#define VMNonatomic
#endif


/*---------------------------------------------------------------------------------
 
 basic types
 
 ----------------------------------------------------------------------------------*/

typedef long			VMInt;
typedef double			VMFloat;
typedef NSTimeInterval 	VMTime;
typedef Float32 		VMVolume;
typedef VMInt 			VMComparatorType;
typedef VMInt			VMOperatorType;
typedef NSString 		VMString;
typedef VMString		VMId;

typedef struct {
	VMFloat minimum;
	VMFloat	maximum;
} VMRange;

typedef struct {
	VMTime	start;
	VMTime	end;
} VMTimeRange;

//#define LengthOfVMRange(range) (range.minimum - range.maximum)
#define LengthOfVMTimeRange(range) (range.end - range.start)
static inline VMRange VMRangeMake(VMFloat min, VMFloat max) {
    VMRange r;
    r.minimum	= min;
    r.maximum	= max;
    return r;
}


//	encoding
#define vmFileEncoding NSASCIIStringEncoding

/*---------------------------------------------------------------------------------
 
 Random Number
 
 ----------------------------------------------------------------------------------*/

#define VMRand1 (((double)arc4random())/0x100000000)	//	0 <= result < 1
#define VMRand(x) (unsigned int)(VMRand1*(x))
//	c func decl.
#ifndef VMPrimitives_h
#define VMPrimitives_h
VMFloat SNDRand(VMFloat center, VMFloat range);
VMFloat limitedSNDRand(VMFloat min, VMFloat max);
#endif



/*---------------------------------------------------------------------------------
 *
 *
 *	Array and Hash
 *
 *
 *---------------------------------------------------------------------------------*/

typedef enum {
	VMSortDirection_ascending = 1,
	VMSortDirection_descending,
} VMSortDirection;

@interface VMArrayBase : NSObject
- (BOOL)object:(id)obj1 isEqualTo:(id)obj2;
- (NSComparisonResult)object:(id)obj1 compare:(id)obj2;
- (VMInt)count;

@end

#pragma mark -
#pragma mark *** array ***

/*
	... we are not quite following the apple's naming convention because
 	syntax like [foo objectAtIndex: bar] is too redundant for my feelings.
 */

/*---------------------------------------------------------------------------------
 *
 *
 *	Array
 *
 *
 *---------------------------------------------------------------------------------*/
@protocol VMBasicArray <NSObject>
@required
//	position
- (BOOL)hasItem:(id)val;
- (VMInt)position:(id)val;
//	get
- (id)item:(VMInt)pos;
- (id)lastItem;
- (VMString*)itemAsString:(VMInt)pos;
- (VMInt)itemAsInt:(VMInt)pos;
- (VMFloat)itemAsFloat:(VMInt)pos;
- (id)itemAsObject:(VMInt)pos;
//	set
- (void)setItem:(id)obj at:(VMInt)pos;
//	push, pop, shift and unshift
- (void)push:(id)obj;
- (id)pop;
//	delete
- (void)deleteItem:(VMInt)pos;
- (void)clear;

- (void)truncateFirst:(VMInt)numberOfDataToLeave;

@end

@class VMHash;

@interface VMArray : VMArrayBase <NSCoding, NSCopying, NSFastEnumeration, VMBasicArray> {
@public
	NSMutableArray *array_;
}
@property (VMReadonly) NSMutableArray *array;
//	get (advanced)
- (VMHash*)itemAsHash:(VMInt)pos;

//	push, pop, shift and unshift (advanced)
- (void)pushUnique:(id)obj;
- (void)append:(VMArray*)arr;
- (void)appendBefore:(VMArray*)arr;
- (void)shift:(id)obj;
- (id)unshift;

//	delete and insert (advanced)
- (void)deleteItemWithValue:(id)val;
- (void)deleteItemsFrom:(VMInt)fromPosition to:(VMInt)toPosition;
- (void)insert:(id)obj at:(VMInt)pos;
- (void)truncateLast:(VMInt)numberOfDataToLeave;
- (void)crop:(VMRange)itemsToLeave;

//	insert and slice, splice
- (void)insertArray:(id)obj at:(VMInt)pos;
//	**	slice and splice are not defined yet.

//	compare
- (BOOL)allValuesAreEqual:(VMArray*)anArray;

//	array creation
+ (id)arrayWithArray:(id)arr;
+ (id)arrayWithObject:(id)obj;
+ (id)arrayWithObjects:(id)firstObj, ...;
+ (id)nullFilledArrayWithSize:(VMInt)size;

//	join and split
+ (VMArray*)arrayWithString:(VMString*)string splitBy:(VMString*)separator;
- (VMString*)join:(VMString*)glue;

//	sort
- (void)sort:(VMSortDirection)direction;

//	misc
- (void)swapItem:(VMInt)p withItem:(VMInt)q;
- (void)reverse;
@end

@interface VMArray(statistics)
//	statistics
- (VMFloat)sum;
- (VMFloat)mean;
- (VMFloat)median;
- (VMFloat)variance;
- (VMFloat)standardDeviation;
- (VMArray*)histogramWithBins:(VMInt)numberOfBins normalize:(BOOL)normalize;
- (VMRange)valueRange;
@end


@interface VMStack : VMArray
@property (nonatomic,VMStrong) id current;
- (void)restore;
@end


#pragma mark -
#pragma mark *** hash ***
#define VMHashKeyType id

/*---------------------------------------------------------------------------------
 *
 *
 *	Hash
 *
 *
 *---------------------------------------------------------------------------------*/


@interface VMHash : VMArrayBase<NSCoding,NSCopying> {
@public
	NSMutableDictionary *hash_;
}
@property (VMReadonly) NSDictionary *hash;

//	get
- (id)item:(VMHashKeyType)key;
- (VMString*)itemAsString:(VMHashKeyType)key;
- (int)itemAsInt:(VMHashKeyType)key;
- (VMFloat)itemAsFloat:(VMHashKeyType)key;
- (VMHash*)itemAsHash:(VMHashKeyType)key;
- (id)itemAsObject:(VMHashKeyType)key;

//	set and remove
- (void)setItem:(id)obj for:(VMHashKeyType)key;
- (void)removeItem:(VMHashKeyType)key;
- (void)clear;

//	push into array item
- (void)push:(id)obj intoArrayItem:(VMHashKeyType)key;
//	add onto item
- (void)add:(VMFloat)num ontoItem:(VMHashKeyType)key;

//	merge
- (void)merge:(VMHash*)aHash;
- (void)deepMerge:(VMHash*)aHash;

//	rename
- (void)renameKey:(VMHashKeyType)oldKey to:(VMHashKeyType)newKey;

//	compare
- (BOOL)allKeysAndValuesAreEqual:(VMHash*)aHash;

//	creation
+ (id)hashWith:(NSDictionary*)dict;	//shortcut for initializing with @{}
+ (id)hashWithDictionary:(id)dict;
+ (id)hashWithObjectsAndKeys:(id)firstObject, ...;

//	keys and values;
- (VMArray*)keys;
- (VMArray*)sortedKeys;
- (VMArray*)keysSortedByValue;
- (VMArray*)values;

@end

#pragma mark ** hashed array ** never used, never tested
// TODO: test before use!
@interface VMHashedArray : VMArrayBase <NSCoding, NSCopying, NSFastEnumeration, VMBasicArray> {
@private
	NSMutableArray		*keys_;
	VMInt				lastIndex;
	unsigned long		keysUpToDate;
	
@public
	NSMutableDictionary	*values_;
}

- (void)setArray:(id)array fromIndex:(VMInt)startIndex;
- (void)deleteItemsExcludingRange:(NSRange)range;

@end

