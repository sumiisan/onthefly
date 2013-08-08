//
//  VMPJSONScanner.m
//  TouchCode
//
//	subclass of CJSONScanner, originally
//  Created by Jonathan Wight on 12/07/2005.
//  Copyright 2005 toxicsoftware.com. All rights reserved.
//

#import "VMPJSONScanner.h"
#import "VMException.h"
#import "CDataScanner_Extensions.h"
#import "MultiPlatform.h"

#if VMP_EDITOR
#import "VMPlayerOSXDelegate.h"
#import "VMPCodeEditorView.h"
#endif

#undef TREAT_COMMENTS_AS_WHITESPACE
#define TREAT_COMMENTS_AS_WHITESPACE 1				//	strip comments

inline static int HexToInt(char inCharacter)
{
    int theValues[] = { 0x0 /* 48 '0' */, 0x1 /* 49 '1' */, 0x2 /* 50 '2' */, 0x3 /* 51 '3' */, 0x4 /* 52 '4' */, 0x5 /* 53 '5' */, 0x6 /* 54 '6' */, 0x7 /* 55 '7' */, 0x8 /* 56 '8' */, 0x9 /* 57 '9' */, -1 /* 58 ':' */, -1 /* 59 ';' */, -1 /* 60 '<' */, -1 /* 61 '=' */, -1 /* 62 '>' */, -1 /* 63 '?' */, -1 /* 64 '@' */, 0xa /* 65 'A' */, 0xb /* 66 'B' */, 0xc /* 67 'C' */, 0xd /* 68 'D' */, 0xe /* 69 'E' */, 0xf /* 70 'F' */, -1 /* 71 'G' */, -1 /* 72 'H' */, -1 /* 73 'I' */, -1 /* 74 'J' */, -1 /* 75 'K' */, -1 /* 76 'L' */, -1 /* 77 'M' */, -1 /* 78 'N' */, -1 /* 79 'O' */, -1 /* 80 'P' */, -1 /* 81 'Q' */, -1 /* 82 'R' */, -1 /* 83 'S' */, -1 /* 84 'T' */, -1 /* 85 'U' */, -1 /* 86 'V' */, -1 /* 87 'W' */, -1 /* 88 'X' */, -1 /* 89 'Y' */, -1 /* 90 'Z' */, -1 /* 91 '[' */, -1 /* 92 '\' */, -1 /* 93 ']' */, -1 /* 94 '^' */, -1 /* 95 '_' */, -1 /* 96 '`' */, 0xa /* 97 'a' */, 0xb /* 98 'b' */, 0xc /* 99 'c' */, 0xd /* 100 'd' */, 0xe /* 101 'e' */, 0xf /* 102 'f' */, };
    if (inCharacter >= '0' && inCharacter <= 'f')
        return(theValues[inCharacter - '0']);
    else
        return(-1);
}


@interface VMPJSONScanner ()
- (BOOL)scanNotQuoteCharactersIntoString:(NSString **)outValue;
- (BOOL)scanNotDoubleColonCharactersIntoString:(NSString **)outValue;	//	ss121208
- (NSError *)error:(NSInteger)inCode description:(NSString *)inDescription;
- (NSError *)error:(NSInteger)inCode description:(NSString *)inDescription withInfo:(NSDictionary *)infoDict;	//	ss extended error report
@end

#pragma mark -

@implementation VMPJSONScanner

static BOOL didThrownError__ = NO;

@synthesize lastKey=lastKey_;

#define ScanInst(scanFunc,errorCode,descriptionString ) \
if ([self scanFunc] == NO) {\
	[self setScanLocation:theScanLocation];\
	if (outError) \
		*outError = [self error:kJSONScannerErrorCode_##errorCode \
						description:descriptionString withInfo:theDictionary];\
	Release( theDictionary );\
	return(NO);\
}

- (id)init {
	self = [super init];
	if (self) {
		didThrownError__ = NO;
	}
	return self;
}



- (void)dealloc {
	VMNullify(lastKey);
	Dealloc( super );;
}

- (BOOL)scanJSONDictionary:(NSDictionary **)outDictionary error:(NSError **)outError {		//	override: customized error out
    NSUInteger theScanLocation = [self scanLocation];	
    [self skipWhitespace];
    if ([self scanCharacter:'{'] == NO) {
        if (outError) {
            *outError = [self error:kJSONScannerErrorCode_DictionaryStartCharacterMissing 
						description:@"Could not scan dictionary. Dictionary that does not start with '{' character."];
		}
        return(NO);
	}
	
    NSMutableDictionary *theDictionary = [[NSMutableDictionary alloc] init];
	
    while ([self currentCharacter] != '}') {
        [self skipWhitespace];
        
        if ([self currentCharacter] == '}')
            break;
		
		NSString *theKey = NULL;
		
		ScanInst(scanJSONStringConstant:&theKey error:outError, DictionaryKeyScanFailed, @"Could not scan dictionary. Failed to scan a key.")
		self.lastKey = AutoRelease([theKey copy]);
		
        [self skipWhitespace];
		
		ScanInst(scanCharacter:':', DictionaryKeyNotTerminated, @"Could not scan dictionary. Key was not terminated with a ':' character.")
		
        id theValue = NULL;
		
		ScanInst(scanJSONObject:&theValue error:outError, DictionaryValueScanFailed, @"Could not scan dictionary. Failed to scan a value.")
		
        if (theValue == NULL && self.nullObject == NULL) {
            // If the value is a null and nullObject is also null then we're skipping this key/value pair.
		} else {
            [theDictionary setValue:theValue forKey:theKey];
		}
		VMNullify(lastKey);
		
        [self skipWhitespace];
		
        if ([self scanCharacter:','] == NO) {
            if ([self currentCharacter] != '}')	{
                [self setScanLocation:theScanLocation];
                if (outError) {
                    *outError = [self error:kJSONScannerErrorCode_DictionaryKeyValuePairNoDelimiter
								description:@"Could not scan dictionary close delimiter."
								 withInfo:theDictionary];
				}
                Release(theDictionary);
                return(NO);
			}
            break;
		} else {
            [self skipWhitespace];
            if ([self currentCharacter] == '}')
                break;
		}
	}
	
	ScanInst(scanCharacter:'}', DictionaryNotTerminated, @"Could not scan dictionary. Dictionary not terminated by a '}' character." )
	
    if (outDictionary != NULL) {
        if (self.options & kJSONScannerOptions_MutableContainers) {
            *outDictionary = AutoRelease( theDictionary );
		} else {
            *outDictionary = AutoRelease([theDictionary copy]);
            Release(theDictionary);
		}
	} else {
        Release(theDictionary);
	}
    return(YES);
}




- (BOOL)scanJSONStringConstant:(NSString **)outStringConstant error:(NSError **)outError	//	override:  double quotes can be omitted.
{
    NSUInteger theScanLocation = [self scanLocation];
	BOOL doubleQuoteWasLeftOut = NO;	//	ss121208
	
    [self skipWhitespace];
	
    NSMutableString *theString = [[NSMutableString alloc] init];
	
    if ([self scanCharacter:'"'] == NO)
	{
		doubleQuoteWasLeftOut = YES;	//	ss	do not throw error
	}
	
	while (( doubleQuoteWasLeftOut  && [self scanCharacter:':'] == NO ) 	//	ss added condition
		   || 
		   ( (!doubleQuoteWasLeftOut) && [self scanCharacter:'"'] == NO ))
	{
        NSString *theStringChunk = NULL;
		
		BOOL stringTerminated = NO;	//	ss
		//	ss121208 ->
		if ( doubleQuoteWasLeftOut ) {
			if ( [self scanNotDoubleColonCharactersIntoString:&theStringChunk] ) {
				CFStringAppend((CFMutableStringRef)theString, (CFStringRef)theStringChunk);
				stringTerminated = YES;
			}
		} else {
			if ([self scanNotQuoteCharactersIntoString:&theStringChunk]) {
				CFStringAppend((CFMutableStringRef)theString, (CFStringRef)theStringChunk);
				stringTerminated = YES;
			}
		}
		//	ss121208 <-
		
		if ( ! stringTerminated ) {
			if( [self scanCharacter:'\\'] == YES)
			{
				unichar theCharacter = [self scanCharacter];
				switch (theCharacter)
				{
					case '"':
					case '\\':
					case '/':
						break;
					case 'b':
						theCharacter = '\b';
						break;
					case 'f':
						theCharacter = '\f';
						break;
					case 'n':
						theCharacter = '\n';
						break;
					case 'r':
						theCharacter = '\r';
						break;
					case 't':
						theCharacter = '\t';
						break;
					case 'u':
					{
						theCharacter = 0;
						
						int theShift;
						for (theShift = 12; theShift >= 0; theShift -= 4)
						{
							const int theDigit = HexToInt([self scanCharacter]);
							if (theDigit == -1)
							{
								[self setScanLocation:theScanLocation];
								if (outError)
								{
									*outError = [self error:kJSONScannerErrorCode_StringUnicodeNotDecoded description:@"Could not scan string constant. Unicode character could not be decoded."];
								}
								Release(theString);
								return(NO);
							}
							theCharacter |= (theDigit << theShift);
						}
					}
						break;
					default:
					{
						if (strictEscapeCodes == YES)
						{
							[self setScanLocation:theScanLocation];
							if (outError)
							{
								*outError = [self error:kJSONScannerErrorCode_StringUnknownEscapeCode description:@"Could not scan string constant. Unknown escape code."];
							}
							Release(theString);
							return(NO);
						}
					}
						break;
				}
				CFStringAppendCharacters((CFMutableStringRef)theString, &theCharacter, 1);
			}
			else
			{
				if (outError)
				{
					*outError = [self error:kJSONScannerErrorCode_StringNotTerminated description:@"Could not scan string constant. No terminating double quote character."];
				}
				Release(theString);
				return(NO);
			}
		}
	}
    if (outStringConstant != NULL)
	{
        if (self.options & kJSONScannerOptions_MutableLeaves)
		{
            *outStringConstant = AutoRelease( theString );
		}
        else
		{
            *outStringConstant = AutoRelease([theString copy]);
            Release(theString);
		}
	}
    else
	{
        Release(theString);
	}
	
	if ( doubleQuoteWasLeftOut ) --current;	//	because we want scan ":" again.	ss121210
    return(YES);
}

#if TREAT_COMMENTS_AS_WHITESPACE
- (void)skipWhitespace		//	override
{
    [super skipWhitespace];
	//	ss121210	support multiple lines of comments at once.
	BOOL caughtComment = YES;
	while ( caughtComment ) {
		caughtComment = [self scanCStyleComment:NULL] || [self scanCPlusPlusStyleComment:NULL];
		[super skipWhitespace];
	}
}
#endif // TREAT_COMMENTS_AS_WHITESPACE

#pragma mark -

- (BOOL)scanNotQuoteCharactersIntoString:(NSString **)outValue
{
    u_int8_t *P;
    for (P = current; P < end && *P != '\"' && *P != '\\'; ++P)
        ;
	
    if (P == current)
	{
        return(NO);
	}
	
    if (outValue)
	{
        *outValue = AutoRelease([[NSString alloc] initWithBytes:current length:P - current encoding:NSUTF8StringEncoding] );
	}
	
    current = P;
	
    return(YES);
}


//	added ss121208 -->
- (BOOL)scanNotDoubleColonCharactersIntoString:(NSString **)outValue {
	u_int8_t *P;
	for (P = current; P < end && *P != ':'; ++P)		//	no escape chars allowed outside of ""
		;
	
	//--P;	//	because we want to scan the last ':' again.
	
	if (P == current)
	{
		return(NO);
	}
	
	if (outValue)
	{
		*outValue = AutoRelease([[NSString alloc] initWithBytes:current length:P - current encoding:NSUTF8StringEncoding] );
	}
	
	current = P;
	
	return(YES);
}
//	<-- ss121208

#pragma mark -

- (NSDictionary *)userInfoForScanLocation		//	override
{
    NSUInteger theLine = 0;
    const u_int8_t *theLineStart = start;
    for (const u_int8_t *C = start; C < current; ++C)
	{
        if (*C == '\n' || *C == '\r')
		{
            theLineStart = C - 1;
            ++theLine;
		}
	}
	
    NSUInteger theCharacter = current - theLineStart;
	
	NSInteger beforeSpan = MIN( (NSInteger)self.scanLocation, 300 );
    NSRange beforeRange = NSIntersectionRange(
											   (NSRange){
												   .location	= self.scanLocation - beforeSpan,
												   .length		= beforeSpan
											   },
											   (NSRange){
												   .location	= 0,
												   .length		= self.data.length
											   });
    NSRange afterRange	= NSIntersectionRange(
											   (NSRange){
												   .location	= self.scanLocation,
												   .length		= 300
											   },
											   (NSRange){
												   .location	= 0,
												   .length		= self.data.length
											   });
	
	
    NSString *beforeSnip = AutoRelease([[NSString alloc] initWithData:[self.data subdataWithRange:beforeRange]
												  encoding:NSUTF8StringEncoding] );
	NSString *afterSnip  = AutoRelease([[NSString alloc] initWithData:[self.data subdataWithRange:afterRange]
												  encoding:NSUTF8StringEncoding] );
	
    NSDictionary *theUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:
								 [NSNumber numberWithUnsignedInteger:theLine], @"line",
								 [NSNumber numberWithUnsignedInteger:theCharacter], @"character",
								 [NSNumber numberWithUnsignedInteger:self.scanLocation], @"location",
								 beforeSnip, @"beforeSnip",
								 afterSnip, @"afterSnip",
								 nil];
    return(theUserInfo);    
}



- (NSError *)error:(NSInteger)inCode description:(NSString *)inDescription	{ //	throw VMException
	return [self error:inCode description:inDescription withInfo:nil];
}

- (NSError *)error:(NSInteger)inCode description:(NSString *)inDescription withInfo:(NSDictionary *)infoDict {	//extended
    NSParameterAssert(inDescription != NULL);
    NSMutableDictionary *theUserInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
										inDescription, NSLocalizedDescriptionKey,
										NULL];
    [theUserInfo addEntriesFromDictionary:self.userInfoForScanLocation];
	NSString *idStr= nil;
	if (infoDict) {
		idStr = [infoDict objectForKey:@"id"];
		if( idStr ) [theUserInfo setObject:idStr forKey:@"id"];
	}
	if ( ! idStr && self.lastKey )
		idStr = self.lastKey;

#if VMP_EDITOR
	
	if ( ! didThrownError__ ) {
		[VMException alert:inDescription
					format:@"%@line:%d charancter:%d location:%d",
		 ( idStr ? [NSString stringWithFormat:@"in definition of \"%@\"\n", idStr] : @"" ),
		 [[theUserInfo objectForKey:@"line"] unsignedIntValue],
		 [[theUserInfo objectForKey:@"character"] unsignedIntValue],
		 [[theUserInfo objectForKey:@"location"] unsignedIntValue]];
				
		didThrownError__ = YES;
		//	highlight error in editor.
		[APPDELEGATE.editorWindowController.codeEditorView
		 markBlockUsingHintsBefore:[theUserInfo objectForKey:@"beforeSnip"] after:[theUserInfo objectForKey:@"afterSnip"]];
	}

#endif
	
	NSError *theError = [NSError errorWithDomain:kJSONScannerErrorDomain code:inCode userInfo:theUserInfo];

	return(theError);

	
}


@end
