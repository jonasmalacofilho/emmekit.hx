package emmekit;

import vehjo.Vector;
using vehjo.NumberPrinter;

class ShapePoint extends Vector {

	public override function toString() : String {
		return x.printDecimal( 1, Node.COORDINATE_PRECISION ) + ' ' + y.printDecimal( 1, Node.COORDINATE_PRECISION );
	}

	public static inline function from_vector( v : Vector ) : ShapePoint {
		return new ShapePoint( v.x, v.y );
	}

}
