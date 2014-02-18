//
//  VMP3D.h
//  OnTheFly
//
//  Created by sumiisan on 2014/01/21.
//
//

#ifndef __OnTheFly__VMP3D__
#define __OnTheFly__VMP3D__

#include <iostream>
#include <math.h>

struct VMVector3 {
	double x;
	double y;
	double z;
};

struct VMQuartenion {
	double t;
	double x;
	double y;
	double z;
};


static VMQuartenion multiply( VMQuartenion lhs, VMQuartenion rhs ) {
	VMQuartenion result;
	double  d1, d2, d3, d4;
	
	d1   =  lhs.t * rhs.t;
	d2   = -lhs.x * rhs.x;
	d3   = -lhs.y * rhs.y;
	d4   = -lhs.z * rhs.z;
	result.t = d1 + d2 + d3 + d4;
	
	d1   =  lhs.t * rhs.x;
	d2   =  rhs.t * lhs.x;
	d3   =  lhs.y * rhs.z;
	d4   = -lhs.z * rhs.y;
	result.x = d1 + d2 + d3 + d4;
	
	d1   =  lhs.t * rhs.y;
	d2   =  rhs.t * lhs.y;
	d3   =  lhs.z * rhs.x;
	d4   = -lhs.x * rhs.z;
	result.y = d1 + d2 + d3 + d4;
	
	d1   =  lhs.t * rhs.z;
	d2   =  rhs.t * lhs.z;
	d3   =  lhs.x * rhs.y;
	d4   = -lhs.y * rhs.x;
	result.z = d1 + d2 + d3 + d4;
	
	return result;
}

static VMQuartenion makeRotationQuartenion( double radian, VMVector3 axis ) {
	VMQuartenion result;
	double   normalizeFactor = axis.x * axis.x +  axis.y * axis.y +  axis.z * axis.z;
	
	if( normalizeFactor <= 0.0 ) return result;
	normalizeFactor = 1.0 / sqrt( normalizeFactor );
		
	double sn = sin(0.5 * radian);
	result.t = cos(0.5 * radian);
	result.x = sn * axis.x * normalizeFactor;
	result.y = sn * axis.y * normalizeFactor;
	result.z = sn * axis.z * normalizeFactor;
	
	return result;
}

static VMVector3 rotate( VMVector3 position, VMVector3 axis, double radian ) {
	VMQuartenion p = { 0, position.x, position.y, position.z };
	VMQuartenion q = makeRotationQuartenion(  radian, axis );
	VMQuartenion r = makeRotationQuartenion( -radian, axis );
	VMQuartenion rp = multiply( r, p );
	VMQuartenion rpq = multiply( rp, q );
	VMVector3 result = { rpq.x, rpq.y, rpq.z };
	return result;
}


#endif /* defined(__OnTheFly__VMP3D__) */
