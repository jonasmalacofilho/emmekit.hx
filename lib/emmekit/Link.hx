package emmekit;

import jonas.ds.RTree;
import jonas.LazyLambda;
import jonas.MathExtension;
import jonas.Maybe;
import emmekit.Element;
import emmekit.Scenario;
using jonas.NumberPrinter;

class Link extends Element {

	/** Definitions **/

	public static inline var DEFAULT_LANES = 0.;
	public static inline var DEFAULT_VDF = 0;
	public static inline var DEFAULT_USER_DATA_VALUE = 0.;
	public static inline var LENGHT_PRECISION = 6;
	public static inline var LANES_PRECISION = 1;
	public static inline var USER_DATA_PRECISION = 2;

	/** Basic struture **/

	public var fr( default, null ) : Node;
	public var to( default, null ) : Node;
	public var len : Float;
	public var mod : String;
	public var typ : Int;
	public var lan : Float;
	public var vdf : Int;
	public var ul1 : Float;
	public var ul2 : Float;
	public var ul3 : Float;

	public var key( default, null ) : TLinkKey;

	/** Link shape **/

	public var inflections( get_inflections, set_inflections ) : LinkInflections;
	var inflx: LinkInflections;
	function get_inflections(): LinkInflections {
		return inflx;
	}
	function set_inflections( inflections: LinkInflections ): LinkInflections {
		s.link_remove_from_rtree( this );
		this.inflx = inflections;
		s.link_add_to_rtree( this );
		return this.inflections;
	}

	/** Basic API **/

	public function new( fr : Node, to : Node, len : Maybe<Float>, mod : String, typ : Int, lan : Float, vdf : Int, ul1 : Float, ul2 : Float, ul3 : Float, inflections : LinkInflections ) {
		if ( fr == to )
			error( 'Cannot create self-loops (links with inode==jnode)' );

		this.fr = fr;
		this.to = to;
		this.len = switch ( len ) {
			case just( v ): v;
			case empty: fr.distance_to( to );
		};
		this.mod = mod;
		this.typ = typ;
		this.lan = lan;
		this.vdf = vdf;
		this.ul1 = ul1;
		this.ul2 = ul2;
		this.ul3 = ul3;
		inflx = inflections;
		key = Element.link_key( fr.i, to.i );

		if ( fr.s != to.s )
			error( 'Nodes must be from the same scenario' );
		super( fr.s );
		fr.link_register( this );
		to.link_register( this );
		id = s.link_register( this );
	}

	public inline function copy( fr : Node, to : Node ) : Link {
		var x = new Link( fr, to, just( len ), mod, typ, lan, vdf, ul1, ul2, ul3, inflections );
		Element.copyAllAttributes( s.link_attributes, this, x );
		return x;
	}

	override function scenario_unregister( s : Scenario ) : Void {
		s.link_unregister( this );
	}

	public override function delete() : Bool {
		if ( !deleted() ) {
			fr.link_unregister( this );
			to.link_unregister( this );
			return super.delete();
		}
		else
			return false;
	}

	public function print_to_buffer( b : StringBuf, compact : Bool, skip_defaults : Bool ) : Void {

		if ( compact ) {

			b.add( ' ' ); b.add( fr.i );
			b.add( ' ' ); b.add( to.i );
			b.add( ' ' ); b.add( ( len ).printDecimal( 1, LENGHT_PRECISION ) );
			b.add( ' ' ); b.add( mod );
			b.add( ' ' ); b.add( typ );
			if ( !skip_defaults || DEFAULT_LANES != MathExtension.round( lan, LANES_PRECISION ) || DEFAULT_VDF != vdf || DEFAULT_USER_DATA_VALUE != ul1 || DEFAULT_USER_DATA_VALUE != ul2 || DEFAULT_USER_DATA_VALUE != ul3 ) {
				b.add( ' ' ); b.add( lan.printDecimal( 1, LANES_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_VDF != vdf || DEFAULT_USER_DATA_VALUE != ul1 || DEFAULT_USER_DATA_VALUE != ul2 || DEFAULT_USER_DATA_VALUE != ul3 ) {
				b.add( ' ' ); b.add( vdf );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ul1 || DEFAULT_USER_DATA_VALUE != ul2 || DEFAULT_USER_DATA_VALUE != ul3 ) {
				b.add( ' ' ); b.add( ul1.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ul2 || DEFAULT_USER_DATA_VALUE != ul3 ) {
				b.add( ' ' ); b.add( ul2.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ul3 ) {
				b.add( ' ' ); b.add( ul3.printDecimal( 1, USER_DATA_PRECISION ) );
			}

		}
		else { // verbose

			b.add( 'i=' ); b.add( fr.i );
			b.add( ' j=' ); b.add( to.i );
			b.add( ' len=' ); b.add( ( len ).printDecimal( 1, LENGHT_PRECISION ) );
			b.add( ' mod=' ); b.add( mod );
			b.add( ' typ=' ); b.add( typ );
			if ( !skip_defaults || DEFAULT_LANES != MathExtension.round( lan, LANES_PRECISION ) ) {
				b.add( ' lan=' ); b.add( lan.printDecimal( 1, LANES_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_VDF != vdf ) {
				b.add( ' vdf=' ); b.add( vdf );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ul1 ) {
				b.add( ' ul1=' ); b.add( ul1.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ul2 ) {
				b.add( ' ul2=' ); b.add( ul2.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ul3 ) {
				b.add( ' ul3=' ); b.add( ul3.printDecimal( 1, USER_DATA_PRECISION ) );
			}

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
		s.link_error( key, msg );
	}

	public function full_shape(): Iterable<ShapePoint> {
		return LazyLambda.concat( [ fr.pt ],
			LazyLambda.concat( inflections, [ to.pt ] ) );
	}

	public function analyze_shape() {
		var pts = full_shape();
		var xmin = Math.POSITIVE_INFINITY, ymin = Math.POSITIVE_INFINITY, xmax = Math.NEGATIVE_INFINITY, ymax = Math.NEGATIVE_INFINITY;
		var len = 0.;
		var pre = null;
		for ( p in pts ) {
			if ( pre != null ) {
				if ( p.x < xmin ) xmin = p.x;
				if ( p.y < ymin ) ymin = p.y;
				if ( p.x > xmax ) xmax = p.x;
				if ( p.y > ymax ) ymax = p.y;
				len += s.distance( pre.x, pre.y, p.x, p.y );
			}
			pre = p;
		}
		return { xmin: xmin, ymin: ymin, xmax: xmax, ymax: ymax, len: len };
	}

	/** Extra attributes API **/

	public override function get( name : String ) : Dynamic { return s.link_attributes.get( name, id ); }

	public override function set( name : String, value : Dynamic ) : Dynamic { return s.link_attributes.set( name, id, value ); }

	/** Modes API **/

	public inline function has_any_of_modes( x : String ) : Bool { return modes_has_any_of_x( mod, x ); }

	public inline function has_all_of_modes( x : String ) : Bool { return modes_has_all_of_x( mod, x ); }

	public function add_mode( x : String ) : Bool {
		var a = modes_add( mod, x );
		if ( mod.length != a.length ) {
			mod = a;
			return true;
		}
		return false;
	}

	public function remove_mode( x : String ) : Bool {
		var a = modes_remove( mod, x );
		if ( mod.length != a.length ) {
			mod = a;
			return true;
		}
		return false;
	}

	public static function modes_add( a : String, x : String ) : String {
		var b = a;
		for ( j in 0...x.length ) {
			var f = false;
			for ( i in 0...b.length )
				if ( b.charAt( i ) == x.charAt( j ) ) {
					f = true;
					break;
				}
			if ( !f )
				b += x.charAt( j );
		}
		return b;
	}

	public static function modes_remove( a : String, x : String ) : String {
		var b = '';
		for ( i in 0...a.length )
			if ( x.indexOf( a.charAt( i ) ) < 0 )
				b += a.charAt( i );
		return b;
	}

	public static function modes_has_any_of_x( a : String, x : String ) : Bool {
		for ( j in 0...x.length )
			for ( i in 0...a.length )
				if ( a.charAt( i ) == x.charAt( j ) )
					return true;
		return false;
	}

	public static function modes_has_all_of_x( a : String, x : String ) : Bool {
		for ( j in 0...x.length ) {
			var f = false;
			for ( i in 0...a.length )
				if ( a.charAt( i ) == x.charAt( j ) ) {
					f = true;
					break;
				}
			if ( !f )
				return false;
		}
		return true;
	}

	public static function add_to_rtree( link: Link, t: RTree<Link> ): Void {
		var pre = null;
		for ( p in link.full_shape() ) {
			if ( pre != null && p.sub( pre ).mod() > 0 ) {
				t.insertRectangle(
					Math.min( pre.x, p.x ),
					Math.min( pre.y, p.y ),
					Math.abs( p.x - pre.x ),
					Math.abs( p.y - pre.y ),
					link
				);
			}
			pre = p;
		}
	}

	public static function remove_from_rtree( link: Link, t: RTree<Link> ): Int {
		var pre = null;
		var maxRemoved = 0;
		for ( p in link.full_shape() ) {
			if ( pre != null ) {
				var rem = t.removeRectangle(
					Math.min( pre.x, p.x ),
					Math.min( pre.y, p.y ),
					Math.abs( p.x - pre.x ),
					Math.abs( p.y - pre.y ),
					link
				);
				if ( rem > maxRemoved )
					maxRemoved = rem;
			}
			pre = p;
		}
		return maxRemoved;
	}

	/**
		Serialization
	**/

	public function hxSerialize( s: haxe.Serializer ): Void {
		s.serialize( fr.i );
		s.serialize( to.i );
		s.serialize( len );
		s.serialize( mod );
		s.serialize( typ );
		s.serialize( lan );
		s.serialize( vdf );
		s.serialize( ul1 );
		s.serialize( ul2 );
		s.serialize( ul3 );
		s.serialize( inflx );
		s.serialize( key );
	}

	public function hxUnserialize( s: haxe.Unserializer ): Void {
		this.s = Scenario.SERIALIZATION_INSTANCE;
		id = Scenario.INVALID_ID;

		fr = this.s.node_get( s.unserialize() );
		to = this.s.node_get( s.unserialize() );
		len = s.unserialize();
		mod = s.unserialize();
		typ = s.unserialize();
		lan = s.unserialize();
		vdf = s.unserialize();
		ul1 = s.unserialize();
		ul2 = s.unserialize();
		ul3 = s.unserialize();
		inflx = s.unserialize();
		key = s.unserialize();

		fr.link_register( this );
		to.link_register( this );
		id = this.s.link_register( this );
	}

}
