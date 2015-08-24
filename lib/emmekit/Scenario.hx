package emmekit;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.BytesData;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Eof;
import haxe.io.Input;
import haxe.io.Output;
import jonas.ds.queue.SimpleFIFO;
import jonas.ds.RjTree;
import jonas.macro.Error;
import jonas.Maybe;
import emmekit.Element;
import emmekit.Line;
import emmekit.Link;
import emmekit.Node;
import emmekit.ExtraAttributeTable;
using jonas.MathExtension;
using jonas.LazyLambda;
using Math;
using Std;
using emmekit.Util;
using jonas.sort.Heapsort;
private typedef L = jonas.LazyLambda;

class Scenario {

	public static inline var INVALID_ID : TElementId = -1;
	
	public var scenario_name : String;
	public var last_id( default, null ) : TElementId;
	
	var nodes : Map<Int, Node>;
	public var node_attributes( default, null ) : ExtraAttributeTable<Dynamic>;
	public var node_count( default, null ) : Int;
	var node_r_tree : RjTree<Node>;
	
	var links : Map<String, Link>;
	public var link_attributes( default, null ) : ExtraAttributeTable<Dynamic>;
	public var link_count( default, null ) : Int;
	var link_r_tree : RjTree<Link>;
	
	var lines : Map<String, Line>;
	public var line_attributes( default, null ) : ExtraAttributeTable<Dynamic>;
	public var line_count( default, null ) : Int;
	
	public var segment_attributes( default, null ) : ExtraAttributeTable<Dynamic>;

	public function new( scenario_name = 'Unnamed scenario' ) {
		this.scenario_name = scenario_name;
		last_id = INVALID_ID;
		
		nodes = new Map();
		node_attributes = new ExtraAttributeTable();
		node_count = 0;
		node_r_tree = new RjTree();
		
		links = new Map();
		link_attributes = new ExtraAttributeTable();
		link_count = 0;
		link_r_tree = new RjTree();
		
		lines = new Map();
		line_attributes = new ExtraAttributeTable();
		line_count = 0;
		
		segment_attributes = new ExtraAttributeTable();
	}
	
	public function copy( scenario_name = 'Unnamed scenario' ) {
		var x = new Scenario( scenario_name );
		
		x.node_attributes = node_attributes.copyStructure();
		x.link_attributes = link_attributes.copyStructure();
		x.line_attributes = line_attributes.copyStructure();
		x.segment_attributes = segment_attributes.copyStructure();

		for ( n in nodes )
			n.copy( x, n.is_zone, n.i, n.xi, n.yi );
		for ( lk in links )
			lk.copy( x.node_get( lk.fr.i ), x.node_get( lk.to.i ) );
		for ( li in lines )
			li.copy( x, li.line, true );
		
		// dynamic overloadable functions
		x.error = error;
		x.warning = warning;
		x.print = print;
		x.distance = distance;
		x.node_error = node_error;
		x.link_error = link_error;
		x.link_join_len = link_join_len;
		x.link_join_mod = link_join_mod;
		x.link_join_lan = link_join_lan;
		x.link_join_typ = link_join_typ;
		x.link_join_vdf = link_join_vdf;
		x.link_join_ul1 = link_join_ul1;
		x.link_join_ul2 = link_join_ul2;
		x.link_join_ul3 = link_join_ul3;
		x.link_join_shapepoints = link_join_shapepoints;
		x.link_join_complementary = link_join_complementary;
		x.line_error = line_error;
		x.segment_error = segment_error;
		x.segment_join_ttf = segment_join_ttf;
		x.segment_join_us1 = segment_join_us1;
		x.segment_join_us2 = segment_join_us2;
		x.segment_join_us3 = segment_join_us3;
		
		return x;
	}
	
	public dynamic function error( msg : String ) : Void { throw '@ scenario ' + scenario_name + ': ' + msg; }
	
	public dynamic function warning( msg : String ) : Void { trace( 'Warning: ' + msg ); }
	
	public dynamic function print( msg : String ) : Void { trace( msg ); }
	
	public dynamic function distance( ax : Float, ay : Float, bx : Float, by : Float ) : Float {
		error( 'Missing implementation for the distance function' );
		return Math.NaN;
	}
	
	public function rev_distance_dx( xi : Float, yi : Float, value : Float, over_scan = .1 ) : Float {
		return ( 1. + over_scan ) * value / distance( xi - .5, yi, xi + .5, yi );
	}
	
	public function rev_distance_dy( xi : Float, yi : Float, value : Float, over_scan = .1 ) : Float {
		return ( 1. + over_scan ) * value / distance( xi, yi - .5, xi, yi + .5 );
	}
	
	/** Nodes basic API **/
	
	public dynamic function node_error( key : Dynamic = '?', msg : String ) : Void {
		error( '@ node ' + key + ': ' + msg );
	}
	
	public inline function node_iterator() : Iterator<Node> { return nodes.iterator(); }
	
	public inline function node_exists( i : TNodeNumber ) : Bool { return nodes.exists( i ); }
	
	public inline function node_get( i : TNodeNumber ) : Node {
		if ( !node_exists( i ) )
			node_error( i, 'Node does not exist' );
		return nodes.get( i );
	}
	
	public inline function node_add( is_zone : Bool, i : TNodeNumber, xi : Float, yi : Float, ui1 : Float = Node.DEFAULT_USER_DATA_VALUE, ui2 : Float = Node.DEFAULT_USER_DATA_VALUE, ui3 : Float = Node.DEFAULT_USER_DATA_VALUE, lab = Node.DEFAULT_LABEL ) : Node {
		return new Node( this, is_zone, i, xi, yi, ui1, ui2, ui3, lab );
	}
	
	public inline function node_copy( i : TNodeNumber, is_zone : Bool, j : TNodeNumber, xj : Float, yj : Float ) : Node {
		return node_get( i ).copy( this, is_zone, j, xj, yj );
	}
	
	public inline function node_remove( i : TNodeNumber ) : Bool {
		return node_get( i ).delete();
	}
	
	public function node_remove_multiple( ? delete : Node -> Bool ) : Int {
		var c = 0;
		if ( null == delete )
			for ( x in nodes )
				c += x.delete() ? 1 : 0;
		else
			for ( x in nodes )
				if ( delete( x ) )
					c += x.delete() ? 1 : 0;
		return c;
	}
	
	public inline function node_distance( i : TNodeNumber, j : TNodeNumber ) : Float {
		return node_get( i ).distance_to( node_get( j ) );
	}
	
	public function node_register( a : Node ) : TElementId {
		if ( nodes.exists( a.i ) ) {
			node_error( a.i, 'Node already exists' );
			return INVALID_ID;
		}
		nodes.set( a.i, a );
		node_r_tree.insertPoint( a.xi, a.yi, a );
		//node_r_tree.insertRectangle( a.xi, a.yi, 0., 0., a ); // for testing purposes only
		node_count++;
		return ++last_id;
	}
	
	public function node_unregister( a : Node ) : Bool {
		if ( nodes.remove( a.i ) ) {
			node_r_tree.removePoint( a.xi, a.yi, a );
			node_count--;
			return true;
		}
		node_error( a.i, 'Node was not properly registered' );
		return false;
	}
	
	public function node_search_rectangle( xi : Float, yi : Float, xj : Float, yj : Float ) : List<Node> {
		if ( xj < xi || yj < yi )
			error( 'xj < xi || yj < yi' );
		return Lambda.list( { iterator : node_r_tree.search.bind( xi, yi, xj - xi, yj - yi ) } );
	}
	
	public function node_search_radius( xi : Float, yi : Float, radius : Float ) : List<Node> {
		var dx = rev_distance_dx( xi, yi, radius, .1 );
		var dy = rev_distance_dy( xi, yi, radius, .1 );
		var r = new List();
		for ( x in node_search_rectangle( xi - dx, yi - dy, xi + dx, yi + dy ) ) {
			//trace( [ x.i, distance( xi, yi, x.xi, x.yi ) ] );
			if ( distance( xi, yi, x.xi, x.yi ) <= radius )
				r.add( x );
		}
		return r;
	}
	
	/** Links basic API **/
	
	public dynamic function link_error( key : Dynamic = '?-?', msg : String ) : Void {
		error( '@ link ' + key + ': ' + msg );
	}
	
	public inline function link_iterator() : Iterator<Link> { return links.iterator(); }
	
	public inline function link_exists( i : TNodeNumber, j : TNodeNumber ) : Bool { return links.exists( link_key( i, j ) ); }
	
	public inline function link_get( i : TNodeNumber, j : TNodeNumber ) : Link {
		var k = link_key( i, j );
		if ( !links.exists( k ) )
			link_error( k, 'Link does not exist' );
		return links.get( k );
	}
	
	public inline function link_add( i : TNodeNumber, j : TNodeNumber, len : Maybe<Float>, mod : String, typ : Int, lan = Link.DEFAULT_LANES, vdf = Link.DEFAULT_VDF, ul1 : Float = Link.DEFAULT_USER_DATA_VALUE, ul2 : Float = Link.DEFAULT_USER_DATA_VALUE, ul3 : Float = Link.DEFAULT_USER_DATA_VALUE, ?shape : LinkInflections ) : Link {
		if ( shape == null )
			shape = new LinkInflections( [] );
		return new Link( node_get( i ), node_get( j ), len, mod, typ, lan, vdf, ul1, ul2, ul3, shape );
	}
	
	public inline function link_copy( i : TNodeNumber, j : TNodeNumber, i2 : TNodeNumber, j2 : TNodeNumber ) : Link {
		return link_get( i, j ).copy( node_get( i2 ), node_get( j2 ) );
	}
	
	public inline function link_remove( i : TNodeNumber, j : TNodeNumber ) : Bool {
		return link_get( i, j ).delete();
	}
	
	public function link_remove_multiple( ? delete : Link -> Bool ) : Int {
		var c = 0;
		if ( null == delete )
			for ( x in links )
				c += x.delete() ? 1 : 0;
		else
			for ( x in links )
				if ( delete( x ) )
					c += x.delete() ? 1 : 0;
		return c;
	}
	
	public function link_add_to_rtree( a: Link ): Void {
		Link.add_to_rtree( a, link_r_tree );
	}

	public function link_register( a : Link ) : TElementId {
		var k = a.key;
		if ( links.exists( k ) ) {
			link_error( k, 'Link already exists' );
			return INVALID_ID;
		}
		links.set( k,  a);
		link_add_to_rtree( a );
		link_count++;
		return ++last_id;
	}

	public function link_remove_from_rtree( a: Link ): Int {
		return Link.remove_from_rtree( a, link_r_tree );
	}
	
	public function link_unregister( a : Link ) : Bool {
		if ( links.remove( a.key ) ) {
			link_remove_from_rtree( a );
			link_count--;
			return true;
		}
		link_error( a.key, 'Link was not properly registered' );
		return false;
	}
	
	public function link_search_rectangle( xi : Float, yi : Float, xj : Float, yj : Float ) : List<Link> {
		if ( xj < xi || yj < yi )
			error( 'xj < xi || yj < yi' );
		return Lambda.list( { iterator : link_r_tree.search.bind( xi, yi, xj - xi, yj - yi ) } );
	}
	
	public function link_search_2d_interval( xi : Float, yi : Float, width : Float, height : Float, over_scan = .1 ) : List<Link> {
		var dx = rev_distance_dx( xi, yi, width, over_scan );
		var dy = rev_distance_dy( xi, yi, height, over_scan );
		return Lambda.list( { iterator : link_r_tree.search.bind( xi - dx, yi - dy, dx * 2., dy * 2. ) } );
	}
	
	static inline function link_key( i : TNodeNumber, j : TNodeNumber ) : TLinkKey { return Element.link_key( i, j ); }
	
	/** Link join API: defaults to average( a, b ) **/
	
	public dynamic function link_join_len( a : Link, b : Link, ?e : Link ) : Maybe<Float> {
		if ( null != e )
			return just( ( a.len + b.len + e.len ) * .5 );
		else
			return just( a.len + b.len );
	}
	
	public dynamic function link_join_mod( a : Link, b : Link, ?e : Link ) : String {
		if ( null != e )
			return Link.modes_add( e.mod, a.mod + b.mod );
		else
			return Link.modes_add( a.mod, b.mod );
	}
	
	public dynamic function link_join_lan( a : Link, b : Link, ?e : Link ) : Float {
		return Math.min( 9.9, ( a.lan * a.len + b.lan * b.len ) / ( a.len + b.len ) + ( ( null != e ) ? e.lan : 0. ) );
	}
	
	public dynamic function link_join_typ( a : Link, b : Link, ?e : Link ) : Int {
		if ( null != e )
			return e.typ;
		else
			return Math.min( a.typ, b.typ ).floor();
	}
	
	public dynamic function link_join_vdf( a : Link, b : Link, ?e : Link ) : Int {
		if ( null != e )
			return e.vdf;
		else
			return Math.min( a.vdf, b.vdf ).floor();
	}
	
	public dynamic function link_join_ul1( a : Link, b : Link, ?e : Link ) : Float {
		if ( null != e )
			return ( a.ul1 * a.len + b.ul1 * b.len + e.ul1 * e.len ) / ( a.len + b.len + e.len );
		else
			return ( a.ul1 * a.len + b.ul1 * b.len ) / ( a.len + b.len );
	}
	
	public dynamic function link_join_ul2( a : Link, b : Link, ?e : Link ) : Float {
		if ( null != e )
			return ( a.ul2 * a.len + b.ul2 * b.len + e.ul2 * e.len ) / ( a.len + b.len + e.len );
		else
			return ( a.ul2 * a.len + b.ul2 * b.len ) / ( a.len + b.len );
	}
	
	public dynamic function link_join_ul3( a : Link, b : Link, ?e : Link ) : Float {
		if ( null != e )
			return ( a.ul3 * a.len + b.ul3 * b.len + e.ul3 * e.len ) / ( a.len + b.len + e.len );
		else
			return ( a.ul3 * a.len + b.ul3 * b.len ) / ( a.len + b.len );
	}
	
	public dynamic function link_join_shapepoints( a : Link, b : Link, ?e : Link ) : LinkInflections {
		if ( null != e )
			return e.inflections.copy();
		else
			return a.inflections.concat( new LinkInflections( [ new ShapePoint( b.fr.xi, b.fr.yi ) ] ) ).concat( b.inflections );
	}
	
	public dynamic function link_join_complementary( a : Link, b : Link, x : Link, created: Bool ) : Void { }
	
	public function link_join( i : TNodeNumber, j : TNodeNumber, k : TNodeNumber ) : Array<Link> {
		var a = link_get( i, k );
		var b = link_get( k, j );
		if ( link_exists( i, j ) ) {
			link_join_complementary( a, b, link_get( i, j ), false );
			return [ a, b ];
		}
		else {
			var p = link_add(
				i, j,
				link_join_len( a, b ),
				link_join_mod( a, b ),
				link_join_typ( a, b ),
				link_join_lan( a, b ),
				link_join_vdf( a, b ),
				link_join_ul1( a, b ),
				link_join_ul2( a, b ),
				link_join_ul3( a, b ),
				link_join_shapepoints( a, b )
			);
			link_join_complementary( a, b, p, true );
			link_attributes.join( a.id, b.id, p.id );
			return [ p ];
		}
	}
	
	/** Lines basic API **/
	
	public dynamic function line_error( key : Dynamic = '?', msg : String ) : Void {
		error( '@ line ' + key + ': ' + msg );
	}
	
	public inline function line_iterator() : Iterator<Line> { return lines.iterator(); }
	
	public inline function line_exists( line : TLineName ) : Bool { return lines.exists( line ); }
	
	public inline function line_get( line : TLineName ) : Line {
		if ( !lines.exists( line ) )
			line_error( line, 'Line does not exist' );
		return lines.get( line );
	}

	public inline function line_add( line : String, mode : String, veh : Int, headway : Float, speed : Float, descr : String, ut1 : Float = Line.USER_DATA_PRECISION, ut2 : Float = Line.USER_DATA_PRECISION, ut3 : Float = Line.USER_DATA_PRECISION ) : Line {
		return new Line( this, line, mode, veh, headway, speed, descr, ut1, ut2, ut3 );
	}
	
	public inline function line_copy( line : TLineName, line2 : TLineName, copy_segments : Bool ) : Line {
		return line_get( line ).copy( this, line2, copy_segments );
	}
	
	public function line_remove( line : TLineName ) : Bool {
		return line_get( line ).delete();
	}
	
	public function line_remove_multiple( ? delete : Line -> Bool ) : Int {
		var c = 0;
		if ( null == delete )
			for ( x in lines )
				c += x.delete() ? 1 : 0;
		else
			for ( x in lines )
				if ( delete( x ) )
					c += x.delete() ? 1 : 0;
		return c;
	}
	
	public function line_register( a : Line ) : TElementId {
		if ( lines.exists( a.line ) ) {
			line_error( a.line, 'Line already exists' );
			return INVALID_ID;
		}
		lines.set( a.line,  a);
		line_count++;
		return ++last_id;
	}
	
	public function line_unregister( a : Line ) : Bool {
		if ( lines.remove( a.line ) ) {
			line_count--;
			return true;
		}
		line_error( a.line, 'Line was not properly registered' );
		return false;
	}
	
	/** Line segments basic API **/
	
	public dynamic function segment_error( key : Dynamic = '?', msg : String ) : Void {
		error( '@ segment ' + key + ': ' + msg );
	}
	
	public inline function segment_add( line : TLineName, pos : Int, node : TNodeNumber, board = true, alight = true, dwt = 0.01, ttf = 0, us1 = 0., us2 = 0., us3 = 0. ) : Segment {
		return new Segment( line_get( line ), pos, node_get( node ), board, alight, dwt, ttf, us1, us2, us3 );
	}
	
	public inline function segment_push( line : TLineName, node : TNodeNumber, board = true, alight = true, dwt = 0.01, ttf = 0, us1 = 0., us2 = 0., us3 = 0. ) : Segment {
		return line_get( line ).segment_push( node_get( node ), board, alight, dwt, ttf, us1, us2, us3 );
	}
	
	public inline function segment_copy( line : TLineName, pos : Int, line2 : TLineName, pos2 : Int ) : Segment {
		return line_get( line ).segment_at( pos ).copy( line_get( line2 ), pos2 );
	}
	
	public function segment_count() : Int {
		return lines.fold( $pre + $x.segment_count(), 0 );
	}

	public function segment_register( a : Segment ) : TElementId {
		return ++last_id;
	}
	
	public function segment_unregister( a : Segment ) : Bool {
		return true;
	}
	
	public dynamic function segment_join_ttf( a : Segment, b : Segment ) : Int { return Math.min( a.ttf, b.ttf ).floor(); }
	
	public dynamic function segment_join_us1( a : Segment, b : Segment ) : Float { return ( a.us1 + b.us1 ) * .5; }
	
	public dynamic function segment_join_us2( a : Segment, b : Segment ) : Float { return ( a.us2 + b.us2 ) * .5; }
	
	public dynamic function segment_join_us3( a : Segment, b : Segment ) : Float { return ( a.us3 + b.us3 ) * .5; }

	
	/** Input API **/
	
	public function eff_read( i : Input ) : Input {
		
		var splitrx = ~/[ ]+/g;
		
		var dictionary = new Map();
		dictionary.set( 'i', 'i' );
		dictionary.set( 'inode', 'i' );
		dictionary.set( 'xi', 'xi' );
		dictionary.set( 'yi', 'yi' );
		dictionary.set( 'ui1', 'ui1' );
		dictionary.set( 'ui2', 'ui2' );
		dictionary.set( 'ui3', 'ui3' );
		dictionary.set( 'lab', 'lab' );
		dictionary.set( 'lbi', 'lab' );
		dictionary.set( 'labi', 'lab' );
		dictionary.set( 'j', 'j' );
		dictionary.set( 'jnode', 'j' );
		dictionary.set( 'len', 'len' );
		dictionary.set( 'length', 'len' );
		dictionary.set( 'mod', 'mod' );
		dictionary.set( 'mode', 'mod' );
		dictionary.set( 'modes', 'mod' );
		dictionary.set( 'typ', 'typ' );
		dictionary.set( 'type', 'typ' );
		dictionary.set( 'lan', 'lan' );
		dictionary.set( 'lanes', 'lan' );
		dictionary.set( 'vdf', 'vdf' );
		dictionary.set( 'ul1', 'ul1' );
		dictionary.set( 'ul2', 'ul2' );
		dictionary.set( 'ul3', 'ul3' );
		dictionary.set( 'line', 'line' );
		dictionary.set( 'lin', 'line' );
		dictionary.set( 'veh', 'veh' );
		dictionary.set( 'vehicle', 'veh' );
		dictionary.set( 'hdw', 'hdw' );
		dictionary.set( 'hdwy', 'hdw' );
		dictionary.set( 'headway', 'hdw' );
		dictionary.set( 'speed', 'speed' );
		dictionary.set( 'spd', 'speed' );
		dictionary.set( 'descr', 'descr' );
		dictionary.set( 'ut1', 'ut1' );
		dictionary.set( 'ut2', 'ut2' );
		dictionary.set( 'ut3', 'ut3' );
		dictionary.set( 'vertex', 'vertex' );
		
		var node_next = new Map();
		node_next.set( '', 'centroid' );
		node_next.set( 'centroid', 'i' );
		node_next.set( 'i', 'xi' );
		node_next.set( 'xi', 'yi' );
		node_next.set( 'yi', 'ui1' );
		node_next.set( 'ui1', 'ui2' );
		node_next.set( 'ui2', 'ui3' );
		node_next.set( 'ui3', 'lab' );
		node_next.set( 'lab', '' );
		
		var link_next = new Map();
		link_next.set( '', 'i' );
		link_next.set( 'i', 'j' );
		link_next.set( 'j', 'len' );
		link_next.set( 'len', 'mod' );
		link_next.set( 'mod', 'typ' );
		link_next.set( 'typ', 'lan' );
		link_next.set( 'lan', 'vdf' );
		link_next.set( 'vdf', 'ul1' );
		link_next.set( 'ul1', 'ul2' );
		link_next.set( 'ul2', 'ul3' );
		link_next.set( 'ul3', '' );
		
		var line_next = new Map();
		line_next.set( '', 'line' );
		line_next.set( 'line', 'mod' );
		line_next.set( 'mod', 'veh' );
		line_next.set( 'veh', 'hdw' );
		line_next.set( 'hdw', 'speed' );
		line_next.set( 'speed', 'descr' );
		line_next.set( 'descr', 'ut1' );
		line_next.set( 'ut1', 'ut2' );
		line_next.set( 'ut2', 'ut3' );
		line_next.set( 'ut3', '' );
		
		var shapepoint_next = new Map();
		shapepoint_next.set( '', 'i' );
		shapepoint_next.set( 'i', 'j' );
		shapepoint_next.set( 'j', 'vertex' );
		shapepoint_next.set( 'vertex', 'xi' );
		shapepoint_next.set( 'xi', 'yi' );
		shapepoint_next.set( 'yi', '' );

		var txt : String;
		
		var rt = TUnknown; // reading type
		var op = OUnknown;
		
		var dfseg : Dynamic = cast { };
		dfseg.dfboard = Segment.DEFAULT_BOARD;
		dfseg.dfalight = Segment.DEFAULT_ALIGHT;
		dfseg.dfdwt = Segment.DEFAULT_DWT;
		dfseg.dfttf = Segment.DEFAULT_TTF;
		dfseg.dfus1 = Segment.DEFAULT_USER_DATA_VALUE;
		dfseg.dfus2 = Segment.DEFAULT_USER_DATA_VALUE;
		dfseg.dfus3 = Segment.DEFAULT_USER_DATA_VALUE;
		dfseg.board = Segment.DEFAULT_BOARD;
		dfseg.alight = Segment.DEFAULT_ALIGHT;
		dfseg.dwt = Segment.DEFAULT_DWT;
		dfseg.ttf = Segment.DEFAULT_TTF;
		dfseg.us1 = Segment.DEFAULT_USER_DATA_VALUE;
		dfseg.us2 = Segment.DEFAULT_USER_DATA_VALUE;
		dfseg.us3 = Segment.DEFAULT_USER_DATA_VALUE;
		var seg : Dynamic = cast { };
		seg = dfseg;
		
		var queue = new SimpleFIFO( 1 );
		
		var save_segment_value = function( name : String, val : Dynamic, default_value : Bool ) : Void {
			Reflect.setField( seg, name, val );
			if ( default_value )
				Reflect.setField( seg, 'df' + name, val );
		};

		var flush_queue = function( line : Line, queue : SimpleFIFO<TNodeNumber> ) : Void {
			if ( !queue.empty() )
				line.segment_push( node_get( queue.get() ), seg.board, seg.alight, seg.dwt, seg.ttf, seg.us1, seg.us2, seg.us3 );
			seg = dfseg;
		};
		
		var dwtrx : EReg = ~/^([<>#+])?([0-9.-]+)$/;
		
		var parse_dwt = function( s : String, default_value : Bool ) {
			if ( dwtrx.match( s ) ) {
				switch ( dwtrx.matched( 1 ) ) {
					case Segment.BOARDING_ONLY :
						save_segment_value( 'board', true, default_value );
						save_segment_value( 'alight', false, default_value );
					case Segment.ALIGHTING_ONLY :
						save_segment_value( 'board', false, default_value );
						save_segment_value( 'alight', true, default_value );
					case Segment.BOARDING_AND_ALIGHTING :
						save_segment_value( 'board', true, default_value );
						save_segment_value( 'alight', true, default_value );
					case Segment.NON_STOP :
						save_segment_value( 'board', false, default_value );
						save_segment_value( 'alight', false, default_value );
					default :
						if ( null == dwtrx.matched( 1 ) )
							if ( 0. == dwtrx.matched( 2 ).parseFloat() ) {
								save_segment_value( 'board', false, default_value );
								save_segment_value( 'alight', false, default_value );
							}
							else {
								save_segment_value( 'board', true, default_value );
								save_segment_value( 'alight', true, default_value );
							}
						else
							warning( 'Unsupported preffix to dwt: ' + dwtrx.matched( 1 ) );
				}
				save_segment_value( 'dwt', dwtrx.matched( 2 ).parseFloat(), default_value );
			}
			else
				error( 'Cannot understand this dwt: ' + s );
		};
		
		var tempInflections: Map<Int, Array<ShapePoint>>;

		var line_number = 0;
		var default_error = error;
		var default_warning = warning;
		error = function( msg : String ) { return default_error( '@ input line ' + line_number + ': ' + msg ); };
		warning = function( msg : String ) { return default_warning( '@ input line ' + line_number + ': ' + msg ); };
		try {
			while ( true ) {
				txt = i.readLine();
				line_number++;
				if ( 0 == txt.length ) continue;
				
				// operation and t record processing
				switch ( txt.charAt( 0 ) ) {
					case 'c', '/' :
						op = OUnknown;
						continue; 
					case 't' :
						if ( rt == TShapePoint ) {
							for ( link in links )
								link.inflections = new LinkInflections( tempInflections.get( link.id ) );
						}
						op = OUnknown;
						var a = splitrx.split( txt );
						if ( 2 > a.length ) error( 'Invalid t record' );
						switch ( a[1] ) {
							case 'nodes' : rt = TNode; print( 'Reading nodes' );
							case 'links' : rt = TLink; print( 'Reading links' );
							case 'lines' : rt = TLine; print( 'Reading lines' );
							case 'linkvertices':
								rt = TShapePoint;
								print( 'Reading link shape points' );
								tempInflections = new Map();
								for ( x in links )
									tempInflections.set( x.id, x.inflections.toArray() );
							default : error( 'Unknown record type: "' + a[1] + '"' );
						}
						if ( 3 <= a.length )
						switch ( a[2] ) {
							case 'init' : warning( '"init" t records not yet supported' );
							default : // nothing to do here
						}
						continue;
					case 'a' :
						op = OAdd;
						switch ( rt ) {
							case TSegment( line ) : flush_queue( line, queue ); rt = TLine;
							default : // nothing to do here
						}
					case 'd' :
						op = ODelete;
						switch ( rt ) {
							case TSegment( line ) : rt = TLine;
							default : // nothing to do here
						}
					case 'm' :
						op = OModify;
						switch ( rt ) {
							case TSegment( line ) : rt = TLine;
							default : // nothing to do here
						}
					case 'r':
						switch ( rt ) {
							case TShapePoint: // ok, nothing to do here
							default: error( 'Unexpected reset "r" operation outside of link shape point transaction file' );
						}
						op = OReset;
					default :
						switch ( rt ) {
							case TSegment( line ) : if ( 1 > txt.length ) continue;
							default : continue;
						}
				}
				
				// other record processing
				switch ( rt ) {
					case TNode :
						
						var values : Dynamic<String> = cast { };
						//trace( txt );
						//trace( txt.charAt( 1 ) );
						values.centroid = txt.charAt( 1 );
						var name = 'centroid';
						for ( p in txt.substr( 2 ).split( ' ' ) ) {
							if ( '' == p ) continue;
							var ep = p.indexOf( '=' );
							var val : String;
							if ( -1 != ep ) {
								name = dictionary.get( p.substr( 0, ep ) );
								val = p.substr( ep + 1 );
							}
							else {
								name = node_next.get( name );
								val = p;
							}
							//trace( { n : name, v : val } );
							Reflect.setField( values, name, val );
						}
						
						switch ( op ) {
							case OAdd :
								if ( !Reflect.hasField( values, 'centroid' ) ) error( 'Missing centroid indication\n' + txt );
								if ( !Reflect.hasField( values, 'i' ) ) error( 'Missing i\n' + txt );
								if ( !Reflect.hasField( values, 'xi' ) ) error( 'Missing xi\n' + txt );
								if ( !Reflect.hasField( values, 'yi' ) ) error( 'Missing yi\n' + txt );
								node_add(
									( '*' == values.centroid ) ? true : false,
									values.i.parseInt(),
									values.xi.parseFloat(),
									values.yi.parseFloat(),
									Reflect.hasField( values, 'ui1' ) ? values.ui1.parseFloat() : Node.DEFAULT_USER_DATA_VALUE,
									Reflect.hasField( values, 'ui2' ) ? values.ui2.parseFloat() : Node.DEFAULT_USER_DATA_VALUE,
									Reflect.hasField( values, 'ui3' ) ? values.ui3.parseFloat() : Node.DEFAULT_USER_DATA_VALUE,
									Reflect.hasField( values, 'lab' ) ? values.lab : Node.DEFAULT_LABEL
								);
							case ODelete :
								if ( !Reflect.hasField( values, 'i' ) ) error( 'Missing i\n' + txt );
								node_remove( values.i.parseInt() );
							case OModify :
								if ( !Reflect.hasField( values, 'i' ) ) error( 'Missing i\n' + txt );
								var n = node_get( values.i.parseInt() );
								for ( fi in Reflect.fields( values ) )
									switch ( fi ) {
										case 'ui1', 'ui2', 'ui3' : Reflect.setField( n, fi, Reflect.field( values, fi ).parseFloat() );
										case 'lab' : Reflect.setField( n, fi, Reflect.field( values, fi ) );
										default : // nothing to do here
									}
							default : // nothing to do here
						}
						
					case TLink :
						
						//trace( txt );
						var values : Dynamic<String> = cast { };
						var two_sided = '=' == txt.charAt( 1 );
						var name = '';
						for ( p in txt.substr( two_sided ? 2 : 1 ).split( ' ' ) ) {
							if ( '' == p ) continue;
							var ep = p.indexOf( '=' );
							var val : String;
							if ( -1 != ep ) {
								name = dictionary.get( p.substr( 0, ep ) );
								val = p.substr( ep + 1 );
							}
							else {
								name = link_next.get( name );
								val = p;
							}
							//trace( { n : name, v : val } );
							Reflect.setField( values, name, val );
						}
						//trace( '"' + Reflect.field( values, 'j' ) + '"' );
						
						switch ( op ) {
							case OAdd :
								if ( !Reflect.hasField( values, 'i' ) ) error( 'Missing i\n' + txt );
								if ( !Reflect.hasField( values, 'j' ) ) error( 'Missing j\n' + txt );
								if ( !Reflect.hasField( values, 'len' ) ) error( 'Missing len\n' + txt );
								if ( !Reflect.hasField( values, 'mod' ) ) error( 'Missing mod\n' + txt );
								if ( !Reflect.hasField( values, 'typ' ) ) error( 'Missing typ\n' + txt );
								var i = values.i.parseInt();
								var j = values.j.parseInt();
								var added = link_add(
									i,
									j,
									( '*' == values.len ) ? empty : just( values.len.parseFloat() ),
									values.mod,
									values.typ.parseInt(),
									Reflect.hasField( values, 'lan' ) ? values.lan.parseFloat() : Link.DEFAULT_LANES,
									Reflect.hasField( values, 'vdf' ) ? values.vdf.parseInt() : Link.DEFAULT_VDF,
									Reflect.hasField( values, 'ul1' ) ? values.ul1.parseFloat() : Link.DEFAULT_USER_DATA_VALUE,
									Reflect.hasField( values, 'ul2' ) ? values.ul2.parseFloat() : Link.DEFAULT_USER_DATA_VALUE,
									Reflect.hasField( values, 'ul3' ) ? values.ul3.parseFloat() : Link.DEFAULT_USER_DATA_VALUE
								);
								if ( two_sided )
									added.copy( node_get( j ), node_get( i ) );
							case ODelete :
								if ( !Reflect.hasField( values, 'i' ) ) error( 'Missing i\n' + txt );
								if ( !Reflect.hasField( values, 'j' ) ) error( 'Missing j\n' + txt );
								link_remove( values.i.parseInt(), values.j.parseInt() );
							case OModify :
								if ( !Reflect.hasField( values, 'i' ) ) error( 'Missing i\n' + txt );
								if ( !Reflect.hasField( values, 'j' ) ) error( 'Missing j\n' + txt );
								var lk = link_get( values.i.parseInt(), values.j.parseInt() );
								for ( fi in Reflect.fields( values ) )
									switch ( fi ) {
										case 'mod' :
											var mod = values.mod;
											switch ( mod.charAt( 0 ) ) {
												case '+' : lk.add_mode( mod.substr( 1 ) );
												case '-' : lk.remove_mode( mod.substr( 1 ) );
												default : lk.mod = mod;
											}
										case 'len' :
											if ( '*' == values.len )
												lk.len = lk.fr.distance_to( lk.to );
											else
												lk.len = values.len.parseFloat();
										case 'lan', 'ul1', 'ul2', 'ul3' : Reflect.setField( lk, fi, Reflect.field( values, fi ).parseFloat() );
										case 'typ', 'vdf' : Reflect.setField( lk, fi, Reflect.field( values, fi ).parseInt() );
										default : // nothing to do here
									}
							default : // nothing to do here
						}
						
					case TLine :
						
						//trace( txt );
						//trace( txt.substr( 1 ) );
						//trace( txt.substr( 1 ).emmeSplit( ' ' ) );
						var values : Dynamic<String> = cast { };
						var name = '';
						//trace( txt.substr( 1 ) );
						//trace( txt.substr( 1 ).emmeSplit( ' ' ).join( '|' ) );
						//throw '';
						for ( p in txt.substr( 1 ).emmeSplit( ' ' ) ) {
							if ( '' == p ) continue;
							var ep = p.indexOf( '=' );
							var val : String;
							if ( -1 != ep ) {
								name = dictionary.get( p.substr( 0, ep ) );
								val = p.substr( ep + 1 );
							}
							else {
								name = line_next.get( name );
								val = p;
							}
							//trace( { n : name, v : val } );
							Reflect.setField( values, name, val );
						}
						//trace( '"' + Reflect.field( values, 'j' ) + '"' );

						switch ( op ) {
							case OAdd :
								if ( !Reflect.hasField( values, 'line' ) ) error( 'Missing line\n' + txt );
								if ( !Reflect.hasField( values, 'mod' ) ) error( 'Missing mode\n' + txt );
								if ( !Reflect.hasField( values, 'veh' ) ) error( 'Missing veh\n' + txt );
								if ( !Reflect.hasField( values, 'hdw' ) ) error( 'Missing headway\n' + txt );
								if ( !Reflect.hasField( values, 'speed' ) ) error( 'Missing speed\n' + txt );
								if ( !Reflect.hasField( values, 'descr' ) ) error( 'Missing descr\n' + txt );
								rt = TSegment( 
									line_add(
										values.line,
										values.mod,
										values.veh.parseInt(),
										values.hdw.parseFloat(),
										values.speed.parseFloat(),
										values.descr,
										Reflect.hasField( values, 'ut1' ) ? values.ut1.parseFloat() : Line.DEFAULT_USER_DATA_VALUE,
										Reflect.hasField( values, 'ut2' ) ? values.ut2.parseFloat() : Line.DEFAULT_USER_DATA_VALUE,
										Reflect.hasField( values, 'ut3' ) ? values.ut3.parseFloat() : Line.DEFAULT_USER_DATA_VALUE
									)
								);
								seg = dfseg;
							case ODelete :
								if ( !Reflect.hasField( values, 'line' ) ) error( 'Missing line\n' + txt );
								line_remove( values.line );
							case OModify :
								if ( !Reflect.hasField( values, 'line' ) ) error( 'Missing line\n' + txt );
								var li = line_get( values.line );
								for ( fi in Reflect.fields( values ) )
									switch ( fi ) {
										case 'hdw' : li.headway = values.hdw.parseFloat();
										case 'speed', 'ut1', 'ut2', 'ut3' : Reflect.setField( li, fi, Reflect.field( values, fi ).parseFloat() );
										case 'veh' : li.veh = values.veh.parseInt();
										case 'mod', 'descr' : Reflect.setField( li, fi, Reflect.field( values, fi ) );
										default : // nothing to do here
									}
							default : // nothing to do here
						}

					case TSegment( line ) :
						
						var values : Dynamic<String> = cast { };
						for ( p in txt.substr( 1 ).split( ' ' ) ) {
							if ( '' == p ) continue;
							var ep : Int = p.indexOf( '=' );
							if ( -1 != ep ) {
								var name : String = p.substr( 0, ep );
								var val = p.substr( ep + 1 );
								switch ( name ) {
									case 'dwt' :
										flush_queue( line, queue );
										parse_dwt( val, true );
										if ( 0 == line.segment_count() ) { // first point has dwt=+0.00
											save_segment_value( 'board', Segment.DEFAULT_BOARD, false );
											save_segment_value( 'alight', Segment.DEFAULT_ALIGHT, false );
											save_segment_value( 'dwt', Segment.DEFAULT_DWT, false );
										}
									case 'ttf' :
										flush_queue( line, queue );
										save_segment_value( name, val.parseInt(), true );
									case 'us1', 'us2', 'us3' :
										flush_queue( line, queue );
										save_segment_value( name, val.parseFloat(), true );
									case 'tdwt' :
										if ( 0 != line.segment_count() )
											parse_dwt( val, false );
									case 'tus1', 'tus2', 'tus3' :
										save_segment_value( name, val.parseFloat(), false );
									case 'path' :
										flush_queue( line, queue ); // not implemented yet
									case 'lay' :
										flush_queue( line, queue ); // not implemented yet
									default : error( 'Unknown keyword: ' + name );
								}
							}
							else {
								flush_queue( line, queue );
								queue.put( p.parseInt() );
							}
						}

					case TShapePoint:

						var values : Dynamic<String> = cast { };

						var name = '';
						for ( p in txt.substr( 1 ).split( ' ' ) ) {
							if ( '' == p ) continue;
							var ep = p.indexOf( '=' );
							var val : String;
							if ( -1 != ep ) {
								name = dictionary.get( p.substr( 0, ep ) );
								val = p.substr( ep + 1 );
							}
							else {
								name = shapepoint_next.get( name );
								val = p;
							}
							Reflect.setField( values, name, val );
						}

						if ( !Reflect.hasField( values, 'i' ) ) error( 'Missing inode\n' + txt );
						if ( !Reflect.hasField( values, 'j' ) ) error( 'Missing jnode\n' + txt );
						var link = link_get( values.i.parseInt(), values.j.parseInt() );

						switch ( op ) {
							case OReset:
								tempInflections.set( link.id, [] );
							case OAdd, OModify:
								if ( !Reflect.hasField( values, 'vertex' ) ) error( 'Missing vertex id\n' + txt );
								if ( !Reflect.hasField( values, 'xi' ) ) error( 'Missing xi\n' + txt );
								if ( !Reflect.hasField( values, 'yi' ) ) error( 'Missing yi\n' + txt );
								var vid = values.vertex.parseInt() - 1;
								var xi = values.xi.parseFloat();
								var yi = values.yi.parseFloat();
								if ( vid > tempInflections.get( link.id ).length )
									warning( 'Left null shape points behind' );
								tempInflections.get( link.id )[vid] = new ShapePoint( xi, yi );
							case ODelete:
								if ( !Reflect.hasField( values, 'vertex' ) ) error( 'Missing vertex id\n' + txt );
								var vid = values.vertex.parseInt() - 1;
								if ( vid >= tempInflections.get( link.id ).length )
									error( 'Cannot delete a link shape point that does not exist' );
								if ( vid == 0 )
									tempInflections.set( link.id, tempInflections.get( link.id ).slice( vid + 1 ) );
								else if ( vid == tempInflections.get( link.id ).length - 1 )
									tempInflections.set( link.id, tempInflections.get( link.id ).slice( 0, vid - 1 ) );
								else if ( tempInflections.get( link.id ).length > 1 )
									tempInflections.set( link.id, tempInflections.get( link.id ).slice( 0, vid - 1 ).concat( tempInflections.get( link.id ).slice( vid + 1 ) ) );
								else
									tempInflections.set( link.id, [] );
							default: // nothing to do here
						}

					default : error( 'Unknown record type: ' + rt );
				}
				
			}
			
		}
		catch ( e : Eof ) { }

		if ( rt == TShapePoint ) {
			for ( link in links )
				link.inflections = new LinkInflections( tempInflections.get( link.id ) );
		}

		error = default_error;
		warning = default_warning;
		
		#if RJTREE_DEBUG
		print( 'Nodes RTree length = ${node_r_tree.length}, max depth = ${node_r_tree.maxDepth()}' );
		print( 'Links RTree length = ${link_r_tree.length}, max depth = ${link_r_tree.maxDepth()}' );
		#end
		
		return i;
	}

	/** Output API **/
	
	public function eff_write_nodes( o : Output, header = '', ?filter : Node -> Bool ) : Output {
		print( 'Writing nodes' );
		if ( null == filter ) filter = function( x ) { return true; };
		
		var buf = new StringBuf();
		buf.add( 'c ' );  buf.add( header.split( '\n' ).join( '\nc ' ) ); buf.add( '\n' );
		
		// nodes
		buf.add( 't nodes\n' );
		var xs = [];
		for ( x in nodes )
			if ( filter( x ) )
				xs.push( x );
		for ( x in xs.heapsort( function( a, b ) { return Reflect.compare( a.is_zone, b.is_zone ) * -2 + Reflect.compare( a.i, b.i ) >= 0; } ) ) {
			buf.add( 'a' );
			x.print_to_buffer( buf, true, true );
			buf.add( '\n' );
		}
		
		o.writeString( buf.toString() );
		return o;
	}
	
	public function eff_write_links( o : Output, header = '', ?filter : Link -> Bool ) : Output {
		print( 'Writing links' );
		if ( null == filter ) filter = function( x ) { return true; };
		
		var buf = new StringBuf();
		buf.add( 'c ' );  buf.add( header.split( '\n' ).join( '\nc ' ) ); buf.add( '\n' );
		
		// links
		buf.add( 't links\n' );
		var xs = [];
		for ( x in links )
			if ( filter( x ) )
				xs.push( x );
		for ( x in xs.heapsort( function( a, b ) { return Reflect.compare( a.fr.i, b.fr.i ) * 2 + Reflect.compare( a.to.i, b.to.i ) >= 0; } ) ) {
			buf.add( 'a' );
			x.print_to_buffer( buf, true, true );
			buf.add( '\n' );
		}
		
		o.writeString( buf.toString() );
		return o;
	}
	
	public function eff_write_lines( o : Output, header = '', ?filter : Line -> Bool ) : Output {
		print( 'Writing lines' );
		if ( null == filter ) filter = function( x ) { return true; };
		
		var buf = new StringBuf();
		buf.add( 'c ' );  buf.add( header.split( '\n' ).join( '\nc ' ) ); buf.add( '\n' );
		
		buf.add( 't lines\n' );
		var xs = [];
		for ( x in lines )
			if ( filter( x ) )
				xs.push( x );
		for ( x in xs.heapsort( function( a, b ) { return Reflect.compare( a.mode, b.mode ) * 2 + Reflect.compare( a.line, b.line ) >= 0; } ) ) {
			buf.add( 'a' );
			x.print_to_buffer( buf, true, true, 'no' );
			buf.add( '\n' );
		}
		
		o.writeString( buf.toString() );
		return o;
	}
	
	public function eff_write_shape_points( o : Output, header = '', ?filter : Link -> Bool ) : Output {
		print( 'Writing shape points transactions' );
		if ( null == filter ) filter = function( x ) { return true; }
		
		var buf = new StringBuf();
		if ( header.length > 0 ) {
			buf.add( 'c ' );
			buf.add( header.split( '\n' ).join( '\nc ' ) );
			buf.add( '\n' );
		}
		buf.add( 't linkvertices\n' );
		var xs = Heapsort.heapsort( links.filter( filter( $x ) && $x.inflections.length > 0 ),
			function ( a, b ) return b.fr.i<a.fr.i || ( a.fr.i==b.fr.i && b.to.i<a.to.i ) );
		for ( x in xs ) {
			var i = 0;
			var id = x.fr.i + ' ' + x.to.i;
			buf.add( 'r $id\n' );
			for ( sp in x.inflections )
				buf.add( 'a $id ${++i} ${sp}\n' );
		}
		
		o.writeString( buf.toString() );
		return o;
	}
	
	/**
	 * Import node attribute (overwriting)
	 */
	public function read_node_attribute( i : Input, name : String, ?regex, ?key , ?value ) {
		if ( null == regex )
			regex = ~/^[ \t]*(\d+)[ \t]+([0-9.-]+)/;
		if ( null == key )
			key = function( r ) { return Std.parseInt( r.matched( 1 ) ); };
		if ( null == value )
			value = function( r ) { return Std.parseFloat( r.matched( 2 ) ); };
		var line = '';
		while ( try { line = i.readLine(); true; } catch ( eof : Eof ) { false; } )
			if ( regex.match( line ) )
				node_get( key( regex ) ).set( name, value( regex ) );
		return i;
	}
	
	/**
	 * Import link attribute (overwriting)
	 */
	public function read_link_attribute( i : Input, name : String, ?regex, ?key , ?value ) {
		if ( null == regex )
			regex = ~/^[ \t]*(\d+)[ \t]+(\d+)[ \t]+([0-9.-]+)/;
		if ( null == key )
			key = function( r ) { return [ Std.parseInt( r.matched( 1 ) ), Std.parseInt( r.matched( 2 ) ) ]; };
		if ( null == value )
			value = function( r ) { return Std.parseFloat( r.matched( 3 ) ); };
		var line = '';
		while ( try { line = i.readLine(); true; } catch ( eof : Eof ) { false; } )
			if ( regex.match( line ) ) {
				var k = key( regex );
				var v = value( regex );
				if ( link_exists( k[0], k[1] ) )
					link_get( k[0], k[1] ).set( name, value( regex ) );
			}
		return i;
	}
	
	/**
	 * Import line attribute (overwriting)
	 */
	public function read_line_attribute( i : Input, name : String, ?regex, ?key , ?value ) {
		if ( null == regex )
			regex = ~/^[ \t]*([ ^\t]+)[ \t]+([0-9.-]+)/;
		if ( null == key )
			key = function( r ) { return r.matched( 1 ); };
		if ( null == value )
			value = function( r ) { return Std.parseFloat( r.matched( 2 ) ); };
		var line = '';
		while ( try { line = i.readLine(); true; } catch ( eof : Eof ) { false; } )
			if ( regex.match( line ) )
				line_get( key( regex ) ).set( name, value( regex ) );
		return i;
	}
	
	/**
	 * Export note attribute
	 */
	public function write_node_attribute( o : Output, name : String, ?skip : Null<Dynamic> ) {
		print( 'Writing node attributes' );
		var b = new StringBuf();
		b.add( '/Node attribute ' );
		b.add( name );
		b.add( '\n' );
		for ( n in nodes ) {
			var v = n.get( name );
			if ( skip != v ) {
				b.add( n.i );
				b.add( ' ' );
				b.add( v );
				b.add( '\n' );
			}
		}
		o.writeString( b.toString() );
		return o;
	}
	
	/**
	 * Export link attribute
	 */
	public function write_link_attribute( o : Output, name : String, ?skip : Null<Dynamic> ) {
		print( 'Writing link attributes' );
		var b = new StringBuf();
		b.add( '/Link attribute ' );
		b.add( name );
		b.add( '\n' );
		for ( lk in links ) {
			var v = lk.get( name );
			if ( skip != v ) {
				b.add( lk.fr.i );
				b.add( ' ' );
				b.add( lk.to.i );
				b.add( ' ' );
				b.add( v );
				b.add( '\n' );
			}
		}
		o.writeString( b.toString() );
		return o;
	}
	
	/**
	 * Export line attribute
	 */
	public function write_line_attribute( o : Output, name : String, ?skip : Null<Dynamic>  ) {
		print( 'Writing line attributes' );
		var b = new StringBuf();
		b.add( '/Line attribute ' );
		b.add( name );
		b.add( '\n' );
		for ( line in lines ) {
			var v = line.get( name );
			if ( skip != v ) {
				b.add( line.line );
				b.add( ' ' );
				b.add( v );
				b.add( '\n' );
			}
		}
		o.writeString( b.toString() );
		return o;
	}

	/**
		Serialization
	**/

	public static inline var SERIALIZATION_FORMAT: String = '2012/11/28';
	public static var SERIALIZATION_INSTANCE: Scenario = null;

	public function hxSerialize( s: haxe.Serializer ): Void {
		SERIALIZATION_INSTANCE = this;
		s.serialize( SERIALIZATION_FORMAT );
		s.serialize( scenario_name );

		print( 'serializing nodes' );
		s.serialize( node_count );
		L.iter( nodes, s.serialize( $x ) );

		print( 'serializing links (and shapes)' );
		s.serialize( link_count );
		L.iter( links, s.serialize( $x ) );

		// print( 'serializing lines' );
		if ( line_count > 0 )
			warning( 'line serialization not implemented, all lines have been ignored' );
		s.serialize( 0 );
		
		// print( 'serializing node extra attribute table' );
		if ( node_attributes.atts().count() > 0 )
			warning( 'node extra attribute table not implemented, all key,values pairs have been ignored' );
		s.serialize( 0 );

		// print( 'serializing link extra attribute table' );
		if ( link_attributes.atts().count() > 0 )
			warning( 'link extra attribute table not implemented, all key,values pairs have been ignored' );
		s.serialize( 0 );

		// print( 'serializing line extra attribute table' );
		if ( line_attributes.atts().count() > 0 )
			warning( 'line extra attribute table not implemented, all key,values pairs have been ignored' );
		s.serialize( 0 );

		// print( 'serializing segment extra attribute table' );
		if ( segment_attributes.atts().count() > 0 )
			warning( 'segment extra attribute table not implemented, all key,values pairs have been ignored' );
		s.serialize( 0 );

		SERIALIZATION_INSTANCE = null;
	}

	public function hxUnserialize( s: haxe.Unserializer ): Void {
		SERIALIZATION_INSTANCE = this;
		var dataFormat = s.unserialize();
		if ( dataFormat != SERIALIZATION_FORMAT )
			warning( 'serialization format used is in version "$dataFormat", while current binary uses "$SERIALIZATION_FORMAT"' );
		this.scenario_name = s.unserialize();
		last_id = INVALID_ID;

		nodes = new Map();
		node_attributes = new ExtraAttributeTable();
		node_count = 0;
		node_r_tree = new RjTree();
		
		links = new Map();
		link_attributes = new ExtraAttributeTable();
		link_count = 0;
		link_r_tree = new RjTree();
		
		lines = new Map();
		line_attributes = new ExtraAttributeTable();
		line_count = 0;
		
		segment_attributes = new ExtraAttributeTable();

		print( 'unserializing nodes' );
		var nodeCount: Int = s.unserialize();
		L.iter( L.lazy( 0...nodeCount ), { s.unserialize(); } );

		print( 'unserializing links (and shapes)' );
		var linkCount: Int = s.unserialize();
		L.iter( L.lazy( 0...linkCount ), { s.unserialize(); } );

		// print( 'unserializing lines' );
		var lineCount: Int = s.unserialize();
		Error.throwIf( lineCount > 0 );

		// print( 'unserializing node extra attribute table' );
		var nodeAttCount: Int = s.unserialize();
		Error.throwIf( nodeAttCount > 0 );

		// print( 'unserializing link extra attribute table' );
		var linkAttCount: Int = s.unserialize();
		Error.throwIf( linkAttCount > 0 );

		// print( 'unserializing line extra attribute table' );
		var lineAttCount: Int = s.unserialize();
		Error.throwIf( lineAttCount > 0 );

		// print( 'unserializing segment extra attribute table' );
		var segmentAttCount: Int = s.unserialize();
		Error.throwIf( segmentAttCount > 0 );

		SERIALIZATION_INSTANCE = null;
	}

	
	
}

private enum ElementType {
	TNode;
	TLink;
	TLine;
	TSegment( line : Line );
	TShapePoint;
	TUnknown;
}

private enum OperationType {
	OAdd;
	ODelete;
	OModify;
	OReset;
	OUnknown;
}
