package emmekit;

typedef TNodeNumber = Int;
typedef TLineName = String;
typedef TLinkKey = String;
typedef TElementId = Int;

// deprecated (mainted only to indicate possible problems with the new, immutable, LinkInflections)
typedef LinkShape = Array<ShapePoint>;

enum ElementType {
	ENode;
	ELink;
	ELine;
	EGeneric;
}

class Element {

	/** Internals **/
	public var id( default, null ) : TElementId;
	public var s( default, null ) : Scenario;

	function new( s : Scenario ) {
		if ( s == null )
			error( 'Cannot create object for null scenario' );
		this.s = s;
		id = Scenario.INVALID_ID;
	}

	function scenario_unregister( s : Scenario ) : Void {
		throw 'Not implemented on base class';
	}

	public function delete() : Bool {
		scenario_unregister( s );
		s = null;
		id = Scenario.INVALID_ID;
		return true;
	}

	public inline function deleted() : Bool {
		return null == s;
	}

	public function get( name : String ) : Dynamic { error( 'Not implemented on base class' ); return cast null; }

	public function set( name : String, value : Dynamic ) : Dynamic { error( 'Not implemented on base class' ); return cast null; }

	/** Error control **/

	public function error( msg : String ) : Void {
		throw msg;
	}

	/** Other **/

	public static inline function link_key( i : TNodeNumber, j : TNodeNumber ) : TLinkKey {
		return i + '-' + j;
	}

	static function copyAllAttributes<A>( table: ExtraAttributeTable<A>, from: Element, to: Element ) {
		for ( att in table.atts() )
			to.set( att, from.get( att ) );
	}

}
