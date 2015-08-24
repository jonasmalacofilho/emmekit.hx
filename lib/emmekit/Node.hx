package emmekit;

import emmekit.Element;
import jonas.Maybe;
using jonas.LazyLambda;
using jonas.NumberPrinter;

private typedef TAdjContainer<A> = List<A>;
private typedef TSegmentContainer<A> = List<A>;

class Node extends Element {

	/**
	 * Printing definitions
	 */

	public static inline var DEFAULT_USER_DATA_VALUE = 0.;
	public static inline var DEFAULT_LABEL = '0000';
	public static inline var COORDINATE_PRECISION = 6;
	public static inline var USER_DATA_PRECISION = 2;

	/**
	 * Basic Emme Node struture
	 */

	public var is_zone( default, null ) : Bool;
	public var i( default, null ) : TNodeNumber;
	public var pt( default, null ): ShapePoint;
	public var ui1 : Float;
	public var ui2 : Float;
	public var ui3 : Float;
	public var lab : String;

	public var xi( get_xi, never ) : Float;
	public var yi( get_yi, never ) : Float;

	function get_xi(): Float { return pt.x; }
	function get_yi(): Float { return pt.y; }

	/**
	 * Links from and to indices
	 */

	var link_from : TAdjContainer<Link>;
	var link_to : TAdjContainer<Link>;

	/**
	 * Segments index
	 */

	var segments : TSegmentContainer<Segment>;

	/**
	 * Basic API
	 */

	public function new( s : Scenario, is_zone : Bool, i : TNodeNumber, xi : Float, yi : Float, ui1 : Float, ui2 : Float, ui3 : Float, lab : String ) {
		this.is_zone = is_zone;
		this.i = i;
		pt = new ShapePoint( xi, yi );
		this.ui1 = ui1;
		this.ui2 = ui2;
		this.ui3 = ui3;
		this.lab = lab;

		link_from = new TAdjContainer();
		link_to = new TAdjContainer();
		segments = new TSegmentContainer();

		super( s );
		id = s.node_register( this );
	}

	public inline function copy( s : Scenario, is_zone : Bool, i : TNodeNumber, xi : Float, yi : Float ) : Node {
		var x = new Node( s, is_zone, i, xi, yi, ui1, ui2, ui3, lab );
		Element.copyAllAttributes( s.node_attributes, this, x );
		return x;
	}

	override function scenario_unregister( s : Scenario ) : Void {
		s.node_unregister( this );
	}

	public override function delete() : Bool {
		if ( !deleted() ) {
			while ( !segments.isEmpty() )
				segments.last().delete();
			while ( !link_from.isEmpty() )
				link_from.last().delete();
			while ( !link_to.isEmpty() )
				link_to.last().delete();
			return super.delete();
		}
		else
			return false;
	}

	public function delete_after_joining() : Bool {
		//trace( segments.length );
		if ( !deleted() ) {
			for ( a in link_from.array() )
				for ( b in link_to.array() )
					if ( b.fr != a.to ) {
						var r = s.link_join( b.fr.i, a.to.i, i );
						if ( r.length == 1 ) {
							a.delete();
							b.delete();
							while ( !segments.isEmpty() ) {
								var s = segments.first();
								if ( s.next().node == a.to )
									s.join_with_next();
							}
						}
					}
			if ( link_from.length==0 && link_to.length==0 && segments.isEmpty() )
				return super.delete();
			else
				return false;
		}
		else
			return false;
	}

	public function print_to_buffer( b : StringBuf, compact : Bool, skip_defaults : Bool ) : Void {

		b.add( is_zone ? '*' : ' ' );

		if ( compact ) {

			b.add( i );
			b.add( ' ' ); b.add( xi.printDecimal( 1, COORDINATE_PRECISION ) );
			b.add( ' ' ); b.add( yi.printDecimal( 1, COORDINATE_PRECISION ) );
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ui1 || DEFAULT_USER_DATA_VALUE != ui2 || DEFAULT_USER_DATA_VALUE != ui3 || DEFAULT_LABEL != lab ) {
				b.add( ' ' ); b.add( ui1.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ui2 || DEFAULT_USER_DATA_VALUE != ui3 || DEFAULT_LABEL != lab ) {
				b.add( ' ' ); b.add( ui2.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ui3 || DEFAULT_LABEL != lab ) {
				b.add( ' ' ); b.add( ui3.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_LABEL != lab ) {
				b.add( ' ' ); b.add( lab.substr( 0, 4 ) );
			}

		}
		else { // verbose

			b.add( 'i=' ); b.add( i );
			b.add( ' xi=' ); b.add( xi.printDecimal( 1, COORDINATE_PRECISION ) );
			b.add( ' yi=' ); b.add( yi.printDecimal( 1, COORDINATE_PRECISION ) );
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ui1 ) {
				b.add( ' ui1=' ); b.add( ui1.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ui2 ) {
				b.add( ' ui2=' ); b.add( ui2.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ui3 ) {
				b.add( ' ui3=' ); b.add( ui3.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_LABEL != lab ) {
				b.add( ' lab=' ); b.add( lab.substr( 0, 4 ) );
			}

		}

		if ( 4 < lab.length ) {
			b.add( ' / ' );
			b.add( lab.substr( 4 ) );
		}

	}

	public inline function toString() : String {
		return print();
	}

	public inline function print( compact = false, skip_defaults = false ) : String {
		var b = new StringBuf();
		print_to_buffer( b, compact, skip_defaults );
		return b.toString();
	}

	public override function error( msg : String ) : Void {
		s.node_error( i, msg );
	}

	public function distance_to( x : Node ) : Float {
		return s.distance( xi, yi, x.xi, x.yi );
	}

	public function nodes_in_radius( r : Float ) : List<Node> {
		return s.node_search_radius( xi, yi, r );
	}

	/** Extra attributes API **/

	public override function get( name : String ) : Dynamic { return s.node_attributes.get( name, id ); }

	public override function set( name : String, value : Dynamic ) : Dynamic { return s.node_attributes.set( name, id, value ); }

	/** Links API **/

	public inline function link_register( x : Link ) : Void {
		if ( this == x.fr )
			link_from.add( x );
		else if ( this == x.to )
			link_to.add( x );
		else
			error( 'Could not register link ' + x.key );
	}

	public inline function link_unregister( x : Link ) : Void {
		if ( this == x.fr )
			link_from.remove( x );
		else if ( this == x.to )
			link_to.remove( x );
		else
			error( 'Could not unregister link ' + x.key );
	}

	public inline function link_from_iterator() : Iterator<Link> { return link_from.iterator(); }

	public inline function link_to_iterator() : Iterator<Link> { return link_to.iterator(); }

	public inline function link_from_count() : Int { return link_from.length; }

	public inline function link_to_count() : Int { return link_to.length; }

	public function link_from_get( x : Node ) : Maybe<Link> {
		for ( lk in link_from )
			if ( x == lk.fr )
				return just( lk );
		return empty;
	}

	public function link_to_get( x : Node ) : Maybe<Link> {
		for ( lk in link_to )
			if ( x == lk.to )
				return just( lk );
		return empty;
	}

	public inline function link_from_filter( f : Link -> Bool ) : TAdjContainer<Link> { return link_from.filter( f ); }

	public inline function link_to_filter( f : Link -> Bool ) : TAdjContainer<Link> { return link_to.filter( f ); }

	public function neighbors() : List<Node> {
		var h = new Map();
		for ( lk in link_from )
			if ( !h.exists( lk.to.i ) )
				h.set( lk.to.i, lk.to );
		for ( lk in link_to )
			if ( !h.exists( lk.fr.i ) )
				h.set( lk.fr.i, lk.fr );
		return Lambda.list( h );
	}

	/** Segments (Lines) API **/

	public inline function segment_register( x : Segment ) : Void {
		segments.add( x );
	}

	public inline function segment_unregister( x : Segment ) : Void {
		segments.remove( x );
	}

	public inline function segment_iterator() : Iterator<Segment> {
		return segments.iterator();
	}

	public inline function segment_count() : Int { return segments.length; }

	public inline function segment_filter( f : Segment -> Bool ) : TSegmentContainer<Segment> { return segments.filter( f ); }

	/**
		Serialization
	**/

	public function hxSerialize( s: haxe.Serializer ): Void {
		s.serialize( is_zone );
		s.serialize( i );
		s.serialize( pt );
		s.serialize( ui1 );
		s.serialize( ui2 );
		s.serialize( ui3 );
		s.serialize( lab );
	}

	public function hxUnserialize( s: haxe.Unserializer ): Void {
		this.s = Scenario.SERIALIZATION_INSTANCE;
		id = Scenario.INVALID_ID;

		is_zone = s.unserialize();
		i = s.unserialize();
		pt = s.unserialize();
		ui1 = s.unserialize();
		ui2 = s.unserialize();
		ui3 = s.unserialize();
		lab = s.unserialize();

		link_from = new TAdjContainer();
		link_to = new TAdjContainer();
		segments = new TSegmentContainer();

		id = this.s.node_register( this );
	}

}
