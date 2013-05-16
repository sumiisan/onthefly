//
//  VMPTest.m
//  OnTheFly
//
//  Created by sumiisan on 2013/05/13.
//
//

#import "VMPTest.h"
#import "VMDataTypes.h"
#import "VMPMacros.h"

#define TEST(name,status,data) if(! (status)) \
NSLog( @"" #name " failed: " #status " %@", (data?data:@""));\
else \
NSLog( @"" #name " OK" );



@implementation VMPTest

//
//	wrote the custom test class because ocunit seems not to work properly
//
+ (void)test {
	NSLog(@"===================== TEST BEGIN ===========================");
	//
	// Id Access
	//
	VMFragment *frag   = ARInstance(VMFragment);
	VMFragment *parent = ARInstance(VMFragment);
	frag.partId = @"part";
	frag.trackId = @"track_yyy";

	TEST(@"Id set(1):",[frag.id isEqualToString:@"part__track_yyy"], frag.id );
	
	frag.trackId = @"track_and_more";
	frag.sectionId = @"section";
	frag.variantId = @"variant";
	frag.VMPModifier = @"vmpmod";
	
	TEST(@"Id set(2):",[frag.id isEqualToString:@"part_section_track_and_more;variant|vmpmod"], frag.id );
	TEST(@"Id get partId",[frag.partId isEqualToString:@"part"], frag.partId );
	TEST(@"Id get sectionId",[frag.sectionId isEqualToString:@"section"], frag.sectionId );
	TEST(@"Id get trackId",[frag.trackId isEqualToString:@"track_and_more"], frag.trackId );
	TEST(@"Id get variantId",[frag.variantId isEqualToString:@"variant"], frag.variantId );
	TEST(@"Id get VMPModifier",[frag.VMPModifier isEqualToString:@"vmpmod"], frag.VMPModifier );
	
	frag.id = @"##track";
	parent.id = @"pirate_of_carribean_jack_sparrow;the|kid";
	
	
	

	NSLog(@"====================== TEST END ==========================");
}


@end
