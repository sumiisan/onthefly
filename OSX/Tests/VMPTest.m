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
#import "VMLog.h"

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
	
	VMHistory *hist = ARInstance(VMHistory);
	
	[hist push:@"A"];
	[hist push:@"B"];
	[hist push:@"B"];
	[hist push:@"C"];
	
	TEST(@"History fwd 1", ![hist canMove: 1],![hist canMove: 1] ? @"YES" : @"NO" );
	TEST(@"History back1", ![hist canMove:-3],![hist canMove:-3] ? @"YES" : @"NO" );
	TEST(@"History back2",  [hist canMove:-2], [hist canMove:-2] ? @"YES" : @"NO" );
	[hist move:-2];
	TEST(@"History item1", [[hist currentItem] isEqualToString:@"A"], hist );
	TEST(@"History fwd 2",  [hist canMove: 1],![hist canMove: 1] ? @"YES" : @"NO" );
	[hist move: 1];
	TEST(@"History item2", [[hist currentItem] isEqualToString:@"B"], hist );
	[hist push:@"D"];
	TEST(@"History item3", [[hist currentItem] isEqualToString:@"D"], hist );
	TEST(@"History count",  [hist count] == 3, hist );
	

	NSLog(@"====================== TEST END ==========================");
}


@end
