package emmekit;

import haxe.io.*;

class Util {

	static inline var SINGLE_QUOTE = "'".code;
	static inline var DOUBLE_QUOTE = '"'.code;

	public static function emmeSplit( s : String, delimiter : String ) : Array<String> {
		var partial = new BytesBuffer();
		var quoted = -1; // not quoted

		var x = Bytes.ofString( s );
		if ( delimiter.length > 1 )
			throw 'does not yet support delimiters with length > 1';
		var d = delimiter.charCodeAt( 0 );

		var results = [];

		for ( i in 0...x.length ) {
			var c = x.get( i );
			if ( c == d ) {
				if ( -1 != quoted ) { // quoted field
					partial.addByte( c );
				}
				else { // unquoted field
					results.push( partial.getBytes().toString() );
					partial = new BytesBuffer();
				}
			}
			else if ( c == SINGLE_QUOTE || c == DOUBLE_QUOTE ) {
				if ( c == quoted ) { // closing quoted part
					quoted = -1;
				}
				else if ( -1 != quoted ) { // quoted field
					partial.addByte( c );
				}
				else { // unquoted field
					quoted = c;
				}
			}
			else {
				partial.addByte( c );
			}
		}

		results.push( partial.getBytes().toString() );
		return results;
	}

	public static function quote( s : String, single = true ) : String {
		if ( single )
			return '\'' + s + '\'';
		else
			return '"' + s + '"';
	}

	static function main() {
		var tests = [ 'a,b,c,d', '"a,b",c,d', 'a,b,"c,d"', 'a,"b,c",d', 'a,"b,c,"d', 'a",b,c",d', 'a,"b,\'c\',"d', 'a",b,\'c\'",d', '"a,b",c,d', 'a,b,"c,d"', 'a,"b,c",d' ];
		for ( x in tests )
			trace( '[${x}] => ${emmeSplit( x, "," ).join( "-" )}' );
	}

}
