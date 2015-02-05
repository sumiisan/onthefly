//
//  TraumBaumTests.m
//  TraumBaumTests
//
//  Created by  on 13/01/11.
//  Copyright (c) 2013 sumiisan (sumiisan.com). All rights reserved.
//

#import "TraumBaumTests.h"
#import "VMDataTypes.h"
#import "VMPMacros.h"

@implementation TraumBaumTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testVMIdAccess {

	VMFragment *frag = ARInstance(VMFragment);
	frag.partId = @"part";
	frag.sectionId = @"sect";
	frag.trackId = @"track";
	frag.variantId = @"variant";
	frag.VMPModifier = @"vmpmod";
	if( ![frag.id isEqualToString:@"part_sect_track;variant|vmpmod"] )
		STFail(@"Id Access Failed %@ != %@", frag.id, @"part_sect_track;variant|vmpmod");
}

- (void)testExample
{
    STFail(@"Unit tests are not implemented yet in TraumBaumTests");
}

@end
