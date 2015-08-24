package emmekit;

class LinkInflections implements ArrayAccess<ShapePoint> {

	var data: Array<ShapePoint>;
	public var length( get_length, null ): Int;

	public function new( inflections: Iterable<ShapePoint> ) {
		data = Lambda.array( inflections );
	}

	public function iterator(): Iterator<ShapePoint> {
		return data.iterator();
	}

	public function slice( pos: Int, ?end: Null<Int> ): LinkInflections {
		var ret = Type.createEmptyInstance( LinkInflections );
		ret.data = data.slice( pos, end );
		return ret;
	}

	public function concat( a: LinkInflections ): LinkInflections {
		var ret = Type.createEmptyInstance( LinkInflections );
		ret.data = data.concat( a.data );
		return ret;
	}

	public function copy(): LinkInflections {
		var ret = Type.createEmptyInstance( LinkInflections );
		ret.data = data.copy();
		return ret;
	}

	public function toArray(): Array<ShapePoint> {
		return data.copy();
	}

	function __get( pos: Int ): ShapePoint {
		return data[pos];
	}

	function __set( pos: Int, v: ShapePoint ): ShapePoint {
		throw 'LinkInflections is read-only';
		return null;
	}

	function get_length(): Int {
		return data.length;
	}

}
