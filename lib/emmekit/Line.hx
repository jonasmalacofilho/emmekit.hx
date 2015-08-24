package emmekit;

using Lambda;

import emmekit.Element;
import emmekit.Scenario;
using emmekit.Util;

import jonas.Maybe;
using jonas.NumberPrinter;

private typedef TSegmentContainer<A> = Array<A>;

class Line extends Element {

	/** Definitions **/
	
	public static inline var DEFAULT_USER_DATA_VALUE = 0.;
	public static inline var HEADWAY_PRECISION = 2;
	public static inline var SPEED_PRECISION = 2;
	public static inline var DESCRIPTION_LENGTH = 20;
	public static inline var USER_DATA_PRECISION = 2;
	
	/** Basic structure **/
	
	public var line( default, null ) : TLineName;
	public var mode : String;
	public var veh : Int;
	public var headway : Float;
	public var speed : Float;
	public var descr : String;
	public var ut1 : Float;
	public var ut2 : Float;
	public var ut3 : Float;
	var segments : TSegmentContainer<Segment>;
	
	/** Basic API **/
	
	public function new( s : Scenario, line : TLineName, mode : String, veh : Int, headway : Float, speed : Float, descr : String, ut1 : Float, ut2 : Float, ut3 : Float ) {
		this.line = line;
		this.mode = mode;
		this.veh = veh;
		this.headway = headway;
		this.speed = speed;
		this.descr = descr;
		this.ut1 = ut1;
		this.ut2 = ut2;
		this.ut3 = ut3;
		
		segments = new TSegmentContainer();
		
		super( s );
		id = s.line_register( this );
	}
	
	public inline function copy( s : Scenario, line : TLineName, copy_segments : Bool ) : Line {
		var a = new Line( s, line, mode, veh, headway, speed, descr, ut1, ut2, ut3 );
		if ( copy_segments )
			if ( s == this.s )
				for ( seg in segments )
					seg.copy( a, seg.pos );
			else
				for ( seg in segments )
					a.segment_push( s.node_get( seg.node.i ), seg.board, seg.alight, seg.dwt, seg.ttf, seg.us1, seg.us2, seg.us3 );
		Element.copyAllAttributes( s.line_attributes, this, a );
		return a;
	}
	
	override function scenario_unregister( s : Scenario ) : Void {
		s.line_unregister( this );
	}
	
	public override function delete() : Bool {
		if ( !deleted() ) {
			var a = true;
			while ( segments.length > 0 )
				a = a && segments[segments.length - 1].delete();
			return a && super.delete();
		}
		else
			return false;
	}
	
	public function print_to_buffer( b : StringBuf, compact : Bool, skip_defaults : Bool, auto_path_mode : String ) : Void {
		
		if ( compact ) {
			
			b.add( line.quote( true ) );
			b.add( ' ' ); b.add( mode );
			b.add( ' ' ); b.add( veh );
			b.add( ' ' ); b.add( headway.printDecimal( 1, HEADWAY_PRECISION ) );
			b.add( ' ' ); b.add( speed.printDecimal( 1, SPEED_PRECISION ) );
			b.add( ' ' ); b.add( descr.substr( 0, DESCRIPTION_LENGTH ).quote( true ) );
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ut1 || DEFAULT_USER_DATA_VALUE != ut2 || DEFAULT_USER_DATA_VALUE != ut3 ) {
				b.add( ' ' ); b.add( ut1.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ut2 || DEFAULT_USER_DATA_VALUE != ut3 ) {
				b.add( ' ' ); b.add( ut2.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ut3 ) {
				b.add( ' ' ); b.add( ut3.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			
		}
		else { // verbose
			
			b.add( 'lin=' ); b.add( line.quote( true ) );
			b.add( ' mod=' ); b.add( mode );
			b.add( ' veh=' ); b.add( veh );
			b.add( ' hdw=' ); b.add( headway.printDecimal( 1, HEADWAY_PRECISION ) );
			b.add( ' spd=' ); b.add( speed.printDecimal( 1, SPEED_PRECISION ) );
			b.add( ' descr=' ); b.add( descr.substr( 0, DESCRIPTION_LENGTH ).quote( true ) );
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ut1 ) {
				b.add( ' ut1=' ); b.add( ut1.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ut2 ) {
				b.add( ' ut2=' ); b.add( ut2.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			if ( !skip_defaults || DEFAULT_USER_DATA_VALUE != ut3 ) {
				b.add( ' ut3=' ); b.add( ut3.printDecimal( 1, USER_DATA_PRECISION ) );
			}
			
		}
		
		switch ( auto_path_mode ) {
			case 'yes': b.add( '\n path=yes' );
			case 'ignore': b.add( '\n path=ignore' );
			default: b.add( '\n path=no' );
		}
		
		for ( seg in segments ) {
			b.add( '\n ' );
			seg.print_to_buffer( b, skip_defaults );
		}
		
	}
	
	public inline function toString() : String {
		return print();
	}
	
	public inline function print( compact = false, skip_defaults = false, auto_path_mode = 'no' ) : String {
		var b = new StringBuf();
		print_to_buffer( b, compact, skip_defaults, auto_path_mode );
		return b.toString();
	}
	
	public override function error( msg : String ) : Void {
		s.line_error( line, msg );
	}
	
	/** Extra attributes API **/
	
	public override function get( name : String ) : Dynamic { return s.line_attributes.get( name, id ); }
	
	public override function set( name : String, value : Dynamic ) : Dynamic { return s.line_attributes.set( name, id, value ); }
	
	/** Segments API **/
	
	public function segment_register( x : Segment ) : Void {
		if ( segments.length == x.pos ) {
			// it's a push op
			segments.push( x );
		}
		else {
			// it's an insertion
			// offsets by +1 all elements after and including x
			var t = segments.slice( 0, x.pos );
			t.push( x );
			segments = t.concat( segments.slice( x.pos ) );
			// updates the position in each one of the shifted elements
			for ( i in ( x.pos + 1 )...segments.length )
				segments[i].unsafe_change_postion( i );
		}
	}
	
	public function segment_unregister( x : Segment, ?unsafe=false ) : Void {
		// determines the neeeded offset to ensure that no X-X exists in path
		var offset = 1;
		if ( 0 < x.pos ) {
			var pre = segments[x.pos - 1];
			var i = x.pos + 1;
			while ( segments.length > i ) {
			//for ( i in x.pos + 1...segments.length )
				if ( !unsafe && pre.node == segments[i].node )
					//offset++;
					segments[i].delete();
				else
					break;
				i++;
			}
		}
		// offsets by -offset all elements after x, already updating their position
		for ( i in x.pos...segments.length - 1 )
			( segments[i] = segments[i + 1] ).unsafe_change_postion( i );
		// pops last element out of the segments array, since it is now duplicated
		//while ( 0 < offset-- )
			segments.pop();
	}
	
	public inline function segment_iterator() : Iterator<Segment> { return segments.iterator(); }
	
	public inline function segment_count() : Int { return segments.length; }
	
	public inline function segment_at( pos : Int ) : Segment { return segments[pos]; }
	
	public inline function segment_push( node : Node, board : Bool, alight : Bool, dwt : Float, ttf : Int, us1 : Float, us2 : Float, us3 : Float ) : Segment {
		return new Segment( this, segment_count(), node, board, alight, dwt, ttf, us1, us2, us3 );
	}
	
	/** Link segment iteraction **/
	
	public function check_links() : Bool {
		for ( i in 1...segments.length ) {
			var checked = false;
			for ( lk in segments[i - 1].node.link_from_iterator() )
				if ( segments[i].node == lk.to )
					checked = lk.has_any_of_modes( mode );
			if ( !checked ) return false;
		}
		return true;
	}
	
	public function adjust_links( len : Maybe<Float>, typ : Int, lan : Float, vdf : Int, ul1 : Float, ul2 : Float, ul3 : Float ) : List<Link> {
		var changed = new List();
		for ( i in 1...segments.length ) {
			var found = false;
			for ( lk in segments[i - 1].node.link_from_iterator() )
				if ( segments[i].node == lk.to ) {
					found = true;
					if ( lk.add_mode( mode ) )
						changed.add( lk );
				}
			if ( !found )
				changed.add( new Link( segments[i - 1].node, segments[i].node, len, mode, typ, lan, vdf, ul1, ul2, ul3, new LinkInflections( [] ) ) );
		}
		return changed;
	}
	
	/** Detours **/
	
	// Detour
	//  -  Inserts all "replace_by" segments using settings from the last
	//      segment before "start" or default settings
	//  -  If a settings transformation has been supplied ("settings"), it is
	//      applied on all created segments
	//  -  Deletes "len" segments starting from "start" (inclusive)
	//  -  ** DEBUG ONLY ** The total segment count of the line is checked against
	//      its expected value
	public function detour_known( start: Segment, len: Int
	  , replace_by: Array<Node>
	  , ?settings: Int -> Segment -> Void ) : Void {

		// input verification
		if ( this != start.line ) error( 'Segment of another line' );
		if ( len < 1 ) error( 'Detour: path to remove must have length >= 1' );

		// reference for settings
		var ref = start.pos > 0? segments[start.pos - 1]: null;

		#if debug
		var expectedFinalLength = segment_count() - len + replace_by.length;
		#end

		// removing old segments
		var p = start.pos;
		for ( i in 0...len )
			if ( segments.length > p ) {
				jonas.macro.Debug.assertTrue( segments[p].pos == p );
				segments[p].delete2( true );
			}

		#if debug
		jonas.macro.Debug.assertTrue( segment_count() == expectedFinalLength - replace_by.length );
		#end

		// inserting new segments
		if ( settings == null )
			settings = function ( i, s ) null;
		if ( ref != null )
			for ( i in 0...replace_by.length )
				settings( i, new Segment( this, p++, replace_by[i]
				    , ref.board, ref.alight, ref.dwt, ref.ttf
				    , ref.us1, ref.us2, ref.us3
				) );
		else
			for ( i in 0...replace_by.length )
				settings( i, s.segment_add( line, p++, replace_by[i].i ) );

		#if debug
		jonas.macro.Debug.assertTrue( segment_count() == expectedFinalLength );
		#end

	}
	
}
