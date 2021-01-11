//
//  VMPVineView.m
//  OnTheFly
//
//  Created by sumiisan on 2015/02/05.
//
//

#import "VMPMacros.h"
#import "VMPVineView.h"
#import "VMPNotification.h"

#define numberOfJoints 12
#define toRadian(degree) ((degree) / 180.0 * M_PI)
static VMFloat reachAngleAtSecond = 5.;
static VMFloat pixelsOf1Second = 1.5;
static VMFloat frameInterval = 0.05;


@interface VMPVinePart ()
@property (nonatomic)		VMTime startTime;
@property (nonatomic)		VMTime sustainTime;
@property (nonatomic)		VMFloat angle;
@end

@implementation VMPVinePart

- (VMTime)elapsed {
	return [[NSDate date] timeIntervalSince1970] - self.startTime;
}

@end

/*---------------------------------------------------------------------------------
 
 VMPLeaf
 
 ----------------------------------------------------------------------------------*/

#pragma mark - VMPLeaf -
@interface VMPLeaf ()
@property (nonatomic)		VMFloat direction;
@end

@implementation VMPLeaf

- (id)init {
	self = [super init];
	if (self) {
		self.strokeColor = [UIColor greenColor].CGColor;
		self.fillColor = [UIColor clearColor].CGColor;
		self.lineWidth = 0.5;
	}
	
	return self;
}

- (void)updateWithPosition:(CGPoint)point angle:(CGFloat)angle {
	VMTime duration = self.sustainTime;
	VMTime elapsed = [self elapsed];
	
	VMFloat t = ( elapsed <= duration ? elapsed : duration - ( elapsed - duration ) );
	if ( t < 0 ) t = 0;

	self.position = point;
	
	if( elapsed < 0 ) {
		self.opacity = 0.;
		return;	//	not yet visible
	} else {
		self.opacity = t;
	}
	
	angle += -45 + self.direction * 90.;
	VMFloat size = t * pixelsOf1Second * 2.;
	
	//	draw leaf
	UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size) cornerRadius:size * 0.2];
	self.path = p.CGPath;
	self.affineTransform = CGAffineTransformMakeRotation(toRadian(-angle));
}

@end








/*---------------------------------------------------------------------------------
 
 VMPCane
 
 ----------------------------------------------------------------------------------*/

#pragma mark - VMPCane -

@interface VMPCane()
@property (nonatomic)			BOOL selected;
@property (nonatomic, retain)	VMArray *leaves;
@end

@implementation VMPCane
@synthesize angleOffset=_angleOffset;//,startTime=_startTime,fragDuration=_fragDuration,selected=_selected;


- (VMFloat)angleOffset {
	return _angleOffset;
}

- (void)setAngleOffset:(VMFloat)angleOffset {
	_angleOffset = angleOffset;
	CGAffineTransform rotate = CGAffineTransformMakeRotation(toRadian(_angleOffset));
	self.affineTransform = rotate;
}

- (void)calculatePointsForTime:(VMTime)elapsed {
	VMFloat angle = sqrt( elapsed / reachAngleAtSecond ) * self.angle * 0.3;
	VMFloat subAngle = angle * 0.07;
	VMFloat anglePerJoint = -angle / (VMFloat)numberOfJoints;
	VMFloat sustain = self.sustainTime;
	VMFloat length = sustain > 0 ? ( elapsed / sustain ) * pixelsOf1Second * sustain : 0;
	
	VMFloat x, y;
	x = y = 0;
	
	UIBezierPath *p = [UIBezierPath bezierPath];
	[p moveToPoint:CGPointZero];
	
	_topAngle = 0;
	[((VMPLeaf*)[self.leaves item:0]) updateWithPosition:CGPointZero angle:_topAngle];
	
	for( int i = 1; i < numberOfJoints; ++i ) {
		VMFloat rad = toRadian( _topAngle );
		x += sin( rad ) * pixelsOf1Second * length;
		y += cos( rad ) * pixelsOf1Second * length;
		[p addLineToPoint:CGPointMake(x, y)];
		_topAngle += anglePerJoint + ( i * subAngle );
		[((VMPLeaf*)[self.leaves item:i]) updateWithPosition:CGPointMake(x, y) angle:_topAngle];
	}
	_topPoint = CGPointMake(x, y);
	
	self.path = p.CGPath;
}

- (id)initWithId:(VMId*)inId
		   angle:(VMFloat)inAngle
		duration:(VMFloat)inDuration
		  weight:(VMFloat)inWeight
		selected:(BOOL)selected
			 hue:(VMFloat)hue {
	
	self = [super init];
	if ( self ) {
		
		self.fragId			= inId;
		self.startTime		= [[NSDate date] timeIntervalSince1970];
		self.sustainTime	= selected ? inDuration : ( inDuration > 3. ? 3. : inDuration );
		self.lineWidth		= inWeight > 0.1 ? inWeight * 3. : 1.;
		self.angle			= inAngle;
		self.selected		= selected;
		
		self.leaves			= ARInstance(VMArray);
		int numLeaves = numberOfJoints;//self.sustainTime / secondsPerLeaf;
		VMFloat flipper = 1;
		for ( int i = 0; i < numLeaves; ++i ) {
			VMPLeaf *leaf = ARInstance(VMPLeaf);
			leaf.startTime   = [[NSDate date] timeIntervalSince1970] + (i * (self.sustainTime / numberOfJoints));
			leaf.sustainTime = self.sustainTime;
			leaf.direction	 = flipper;
			flipper *= -1;
			[self.leaves push:leaf];
			[self addSublayer:leaf];
		}
		
		CGMutablePathRef p = CGPathCreateMutable();
		CGPathMoveToPoint(p , nil, 0, 0);
		self.path = p;
		[self calculatePointsForTime:0.];
		
	//	self.strokeColor = selected ? [UIColor colorWithHue:hue saturation:1. brightness:1. alpha:1.].CGColor : [UIColor grayColor].CGColor;
		self.strokeColor = [UIColor colorWithWhite:0.6 alpha:1.].CGColor;
		self.fillColor = [UIColor clearColor].CGColor;
	}
	
	[self performSelector:@selector(perFrameHook:) withObject:self afterDelay:frameInterval];
	
/*	NSLog(@"[new cane] %@ id:%@ ang:%.2f dur:%.2f wgt:%.2f", (selected ? @"*" : @"" ),
		  inId, self.angle, self.sustainTime, inWeight*3. );
*/
	return self;
}

- (void)perFrameHook:(id)object {
	VMTime duration = self.sustainTime;
	VMTime elapsed = [self elapsed];
	VMTime overtime = elapsed - duration;
	if( overtime > duration ) {
		[self removeFromSuperlayer];
	} else {
		[self performSelector:@selector(perFrameHook:) withObject:self afterDelay:frameInterval];
		if( overtime > 0 ) {
			VMFloat r = overtime / duration;
			if( !_selected ) {
				[self calculatePointsForTime:elapsed];
			}
			self.strokeColor = [UIColor colorWithWhite:0.6 + (r*0.4) alpha:0.5 + (r*0.5)].CGColor;
		//	self.opacity = 1.-r;
		} else {
			[self calculatePointsForTime:elapsed];
		//	self.opacity = 1.;
		}
	}
}

- (void)dealloc {
	VMNullify(leaves);
	VMNullify(fragId);
	Dealloc(super);
}

@end


















/*---------------------------------------------------------------------------------
 
 VMPVineView
 
 ----------------------------------------------------------------------------------*/

#pragma mark - VMPVineView -

@interface VMPVineView()
@property (nonatomic) VMPPoint currentOrigin;
@property (nonatomic) VMFloat currentAngle;
@property (nonatomic, retain) VMPCane *selectedCane;
@property (nonatomic) VMFloat hue;
@property (nonatomic, retain) CALayer *baseLayer;

@property (nonatomic) VMFloat basePaneAngle;
@property (nonatomic, retain) CAShapeLayer *centerMarkerShape;
@property (nonatomic) VMPPoint chaseVector;

@property (nonatomic, retain) VMHash *scoresOfCandidates;
@end

@implementation VMPVineView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

static NSArray *maxAngleForBranch;

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if( self ) {
		[VMPNotificationCenter addObserver:self
								  selector:@selector(processObject:)
									  name:VMPNotificationProcessObject
									object:nil];
		self.currentOrigin = VMPPointZero;
		self.basePaneAngle = self.currentAngle = 180;
		maxAngleForBranch=[@[@( 0.* 0.),@( 0.* 1.),@(90.* 2.),@(62.* 3.),@(50. * 4.),
							 @(45.* 5.),@(41.* 6.),@(38.* 7.),@(35.* 8.),@(32. * 9.),
							 @(30.*10.),@(28.*11.),@(26.*12.),@(24.*13.),@(23.5*14.),
							 @(22.*15.),@(21.*16.),@(20.*17.),@(19.*18.),@(18. *19.)] retain];
		
		self.baseLayer = ARInstance(CALayer);
		self.layer.anchorPoint = CGPointMake(0,0);

		self.baseLayer.backgroundColor = [UIColor clearColor].CGColor;
		[self.layer addSublayer:_baseLayer];
		[self performSelector:@selector(moveBasePane:) withObject:nil afterDelay:0.1];
	/*
		self.centerMarkerShape = ARInstance(CAShapeLayer);
		_centerMarkerShape.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(-5, -5, 10, 10)].CGPath;
		_centerMarkerShape.fillColor = [UIColor redColor].CGColor;
		[_baseLayer addSublayer:_centerMarkerShape];
	*/
	}
	return self;
}

- (void)dealloc {
	VMNullify(scoresOfCandidates);
	VMNullify(centerMarkerShape);
	VMNullify(selectedCane);
	VMNullify(baseLayer);
	Dealloc(super);
}

VMPPoint rotatePointAboutOrigin(VMPPoint point, VMFloat degree) {
	VMFloat radian = toRadian(degree);
	VMFloat s = sin(radian);
	VMFloat c = cos(radian);
	return CGPointMake(c * point.x - s * point.y, s * point.x + c * point.y);
}



- (void)processObject:(NSNotification *)notification {

	NSDictionary	*info = [notification userInfo];
	VMFragment		*fragment			= info[@"fragment"];
	
	VMArray			*branches;
	
	if ( fragment.type == vmObjectType_selector ) {
		if( _scoresOfCandidates == nil ) {
			/*
			 1.
			 if received a selector (first time),
			 collect scores of branches and save it.
			 */
			self.scoresOfCandidates = [ClassCast(fragment, VMSelector) collectScoresOfFragments:0. frameOffset:0 normalize:YES];
			NSLog(@"sel start");
			return;
		} else {
			/*
			 2.
			 ignore following selectors. they shold be already processed in phase (1)
			 */
			NSLog(@"igcore sel");
			return;
		}
	} else if ( fragment.type == vmObjectType_audioFragment ) {
		branches = ARInstance(VMArray);
		BOOL anySelectedFrag = NO;
		if( _scoresOfCandidates ) {
			/*
			 3.
			 if we have saved candidates, create branch.
			 */
			
			VMId	*selectedFragId = fragment.id;
			VMArray *candidateIds = [_scoresOfCandidates keys];
			for( VMId *candidateId in candidateIds ) {
				VMFragment *candidateFragment = [CURRENTSONG data:candidateId];
				
				while( candidateFragment.type == vmObjectType_sequence ) {
					//	just select 1st fragment in sequence
					candidateFragment = [ClassCast(candidateFragment, VMSequence) fragmentAtIndex:0];
					//fragId = candidateFragment.id;
				}
				
				if( candidateFragment.type != vmObjectType_audioFragment ) {
					NSLog(@"Candidate is not audio_fragment! : %@", candidateId );
					//	it can happen, for example, if the 1st fragment in sequence is selector. (and it has conditional options)
					continue;	//	skip, provisory
				}
				
				BOOL sel = [selectedFragId isEqual:candidateFragment.id];
				anySelectedFrag |= sel;
				
				[branches push:[VMHash hashWithObjectsAndKeys:
								candidateFragment.id, @"id",		//	not equal to candidateId if the candidate is a sequence.
								[_scoresOfCandidates item:candidateId], @"score",
								VMBoolObj(sel), @"selected",
								VMFloatObj(ClassCast(candidateFragment, VMAudioFragment).duration), @"duration",
								nil
								]];
			}
			if (!anySelectedFrag) {
				NSLog(@"no selected frag!");
				int r = VMRand(branches.count);
				[[branches item:r] setObject:VMBoolObj(YES) forKey:@"selected"];	//	select any frag. (just juggling)
			} else {
				NSLog(@"branch out %ld",candidateIds.count);
			}
			self.scoresOfCandidates = nil;		//	empty candidates and make ready to retrieve next candidates
		} else {
			/*
			 4.
			 or just a stem without branch-outs.
			 */
			NSLog(@"stem");
			[branches push:[VMHash hashWithObjectsAndKeys:
							fragment.id, @"id",
							@1., @"score",
							VMBoolObj(YES),@"selected",
							@((ClassCast(fragment, VMAudioFragment)).duration), @"duration",
						   nil
						   ]];
			
		}
	} else {
		NSLog(@"could not process object %@", fragment.id);
		assert(0);
		
		//	.
	}
	
	/*
	 
	 4.
	 make cane of branches
	 
	 */
	[branches sortByHashContentKey:@"score"];
	
	int flipper = ( VMRand(2) * 2 ) -1;
	int numBranches = branches.count;
	VMFloat anglePerBranch = AsVMFloatObj(maxAngleForBranch[branches.count <= 19 ? branches.count : 19]) / (VMFloat)numBranches;
	
	VMFloat dist = ( numBranches % 2 ) == 1 ? 0 : 0.5;
	
	if( _selectedCane ) {
		_currentOrigin = [_selectedCane convertPoint:_selectedCane.topPoint toLayer:_baseLayer];
		_chaseVector = CGPointZero;
		_currentAngle -= _selectedCane.topAngle;
	}

	//NSLog(@"\n-----\n %d",numBranches);
	for (VMInt i = 0; i < numBranches; ++i) {
		flipper = -flipper;
		VMHash *branch = [branches item:i];
		BOOL selected = [branch itemAsBool:@"selected"];
		VMFloat ang = dist * anglePerBranch * flipper;
		//NSLog(@"[%.2f = %.2f * %.2f * %d]",ang,dist,anglePerBranch,flipper);
		
		VMFloat duration = [branch itemAsFloat:@"duration"];
		
		VMPCane *vine = [[[VMPCane alloc] initWithId:[branch item:@"id"]
											   angle:ang
											duration:( duration > 0 ? duration : 4 )
											  weight:0.5//[branch itemAsFloat:@"score"]
											selected:selected
												 hue:self.hue
											] autorelease];
		if( selected ) {
			self.selectedCane = vine;
		}
		[_baseLayer addSublayer:vine];
		vine.angleOffset = _currentAngle;
		vine.position = _currentOrigin;
		if(( i % 2 ) != ( numBranches % 2 ) ) dist += 1;
	}
	
	self.hue += 0.1;
	if( self.hue > 1 ) self.hue -= 1;
}

- (void)moveBasePane:(id)info {
	
	CGPoint p = _currentOrigin;
	CGFloat t = _currentAngle;
	
	if( _selectedCane ) {
		p = [_selectedCane convertPoint:_selectedCane.topPoint toLayer:_baseLayer];
		t = _currentAngle - _selectedCane.topAngle;
	}
	
	_baseLayer.anchorPoint = CGPointMake( p.x, p.y );
	//_centerMarkerShape.position = p;
	
	//
	//
	//
	CGPoint ap = [_baseLayer convertPoint:p toLayer:self.layer];
	_chaseVector.x = _chaseVector.x * 0.3 + ap.x * 0.7;
	_chaseVector.y = _chaseVector.y * 0.3 + ap.y * 0.7;
	_baseLayer.position = CGPointMake( _baseLayer.position.x - _chaseVector.x, _baseLayer.position.y - _chaseVector.y );
	//_currentOrigin = _baseLayer.position;//CGPointMake(_currentOrigin.x - _chaseVector.x, _currentOrigin.y - _chaseVector.y);
	
	VMFloat d = t - _basePaneAngle;
	if ( d >  3 ) d  = 3;
	if ( d < -3 ) d = -3;
	_basePaneAngle += d;
	
	_baseLayer.affineTransform = CGAffineTransformMakeRotation(toRadian(180-_basePaneAngle));
	[self performSelector:@selector(moveBasePane:) withObject:nil afterDelay:0.1];
}

@end
