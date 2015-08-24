package emmekit;

using jonas.NumberPrinter;

class Segment extends Element {

	/** Definitions **/

	public static inline var DEFAULT_BOARD = true;
	public static inline var DEFAULT_ALIGHT = true;
	public static inline var DEFAULT_DWT = 0.01;
	public static inline var DEFAULT_TTF = 0;
	public static inline var DEFAULT_USER_DATA_VALUE = 0.;
	public static inline var BOARDING_ONLY = '<';
	public static inline var ALIGHTING_ONLY = '>';
	public static inline var NON_STOP = '#';
	public static inline var BOARDING_AND_ALIGHTING = '+';
	public static inline var DWT_PRECISION = 2;
	public static inline var USER_DATA_PRECISION = 2;

	public var line( default, null ) : Line;
	public var pos( default, null ) : Int;
	public var node( default, null ) : Node;
	public var board : Bool;
	public var alight : Bool;
	public var dwt : Float;
	public var ttf : Int;
	public var us1 : Float;
	public var us2 : Float;
	public var us3 : Float;

	public function new( line : Line, pos : Int, node : Node, board : Bool, alight : Bool, dwt : Float, ttf : Int, us1 : Float, us2 : Float, us3 : Float ) {
		// trace( 'creating segment ' + node.i );
		this.line = line;
		this.pos = pos;
		this.node = node;
		this.board = board;
		this.alight = alight;
		this.dwt = dwt;
		this.ttf = ttf;
		this.us1 = us1;
		this.us2 = us2;
		this.us3 = us3;

		super( line.s );
		line.segment_register( this );
		node.segment_register( this );
		id = s.segment_register( this );
	}

	public function copy( line : Line, pos : Int ) : Segment {
		var x = new Segment( line, pos, line.s.node_get( node.i ), board, alight, dwt, ttf, us1, us2, us3 );
		Element.copyAllAttributes( s.segment_attributes, this, x );
		return x;
	}

	public function unsafe_change_postion( pos : Int ) : Void {
		this.pos = pos;
	}

	override function scenario_unregister( s : Scenario ) : Void {
		s.segment_unregister( this );
	}

	public override function delete() : Bool {
		return delete2();
	}

	public function delete2( ?unsafe=false ) : Bool {
		// trace( 'deleting segment ' + node.i );
		if ( !deleted() ) {
			line.segment_unregister( this, unsafe );
			node.segment_unregister( this );
			return super.delete();
		}
		else
			return false;
	}

	public function join_with_next() : Bool {
		var p = pos + 1;
		//trace( line.segment_count() > p );
		if ( line.segment_count() > p ) {
			var next = line.segment_at( p );
			next.ttf = s.segment_join_ttf( this, next );
			next.us1 = s.segment_join_us1( this, next );
			next.us2 = s.segment_join_us2( this, next );
			next.us3 = s.segment_join_us3( this, next );
			return delete();
		}
		return false;
	}

	public function next(): Null<Segment> {
		var p = pos + 1;
		if ( line.segment_count() > p )
			return line.segment_at( p );
		return null;
	}

	public function print_to_buffer( b : StringBuf, skip_defaults : Bool ) : Void {

		if ( skip_defaults && 0 != pos ) {

			var pre = line.segment_at( pos - 1 );

			if ( pre.dwt != dwt || pre.board != board || pre.alight != alight ) {
				b.add( ' dwt=' );
				if ( board )
					if ( alight )
						b.add( BOARDING_AND_ALIGHTING );
					else
						b.add( BOARDING_ONLY );
				else
					if ( alight )
						b.add( ALIGHTING_ONLY );
					else
						b.add( NON_STOP );
				b.add( dwt.printDecimal( 1, DWT_PRECISION ) );
			}

			b.add( ' ' ); b.add( node.i );

			if ( pre.ttf != ttf ) {
				b.add( ' ttf=' ); b.add( ttf );
			}
			if ( pre.us1 != us1 ) {
				b.add( ' us1=' ); b.add( us1.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( pre.us2 != us2 ) {
				b.add( ' us2=' ); b.add( us2.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( pre.us3 != us3 ) {
				b.add( ' us3=' ); b.add( us3.printDecimal( 1, USER_DATA_PRECISION ) );
			}

		}
		else {

			b.add( ' dwt=' );
			if ( board )
				if ( alight )
					b.add( BOARDING_AND_ALIGHTING );
				else
					b.add( BOARDING_ONLY );
			else
				if ( alight )
					b.add( ALIGHTING_ONLY );
				else
					b.add( NON_STOP );
			b.add( dwt.printDecimal( 1, DWT_PRECISION ) );

			b.add( ' ' ); b.add( node.i );

			b.add( ' ttf=' ); b.add( ttf );
			b.add( ' us1=' ); b.add( us1.printDecimal( 1, USER_DATA_PRECISION ) );
			b.add( ' us2=' ); b.add( us2.printDecimal( 1, USER_DATA_PRECISION ) );
			b.add( ' us3=' ); b.add( us3.printDecimal( 1, USER_DATA_PRECISION ) );

		}

	}

	public inline function toString() : String {
		return print();
	}

	public inline function print( skip_defaults = false ) : String {
		var b = new StringBuf();
		print_to_buffer( b, skip_defaults );
		return b.toString();
	}

	public override function error( msg : String ) : Void {
		s.segment_error( line.line + ':' + pos + ':' + node.i, msg );
	}

	/** Extra attributes API **/

	public override function get( name : String ) : Dynamic { return s.segment_attributes.get( name, id ); }

	public override function set( name : String, value : Dynamic ) : Dynamic { return s.segment_attributes.set( name, id, value ); }

}
