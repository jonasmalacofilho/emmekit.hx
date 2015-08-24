package emmekit;

import emmekit.Element;

class ExtraAttributeTable<A> {
	
	var t : Hash<ExtraAttributeDefinition<A>>;

	public function new() {
		t = new Hash();
	}
	
	/**
	 * Adds attribute [name] to the table
	 */
	public inline function attribute_add( name : String, default_value : A, join : A -> A -> A ) : Void {
		if ( t.exists( name ) )
			error( 'Attribute ' + name + ' already exists.' );
		else 
			t.set( name, new ExtraAttributeDefinition( default_value, join ) );
	}
	
	/**
	 * Removes (deletes) attribute [name] to the table
	 * Returns true if any state is changed
	 */
	public inline function attribute_remove( name : String ) : Bool {
		return t.remove( name );
	}
	
	/**
	 * Gets attribute [name] for element [id]
	 */
	public inline function get( name : String, id : TElementId ) : A {
		var a = t.get( name );
		if ( null == a )
			error( 'No attribute by the name ' + name );
		if ( a.v.exists( id ) )
			return a.v.get( id );
		else
			return a.d;
	}
	
	/**
	 * Sets attribute [name] = [value] for element [id]
	 * Returns [value]
	 */
	public inline function set( name : String, id : TElementId, value : A ) : A {
		var a = t.get( name );
		if ( null == a )
			error( 'No attribute by the name ' + name );
		if ( value == a.d )
			a.v.remove( id );
		else
			a.v.set( id, value );
		return value;
	}
	
	/**
	 * Resets (to default value) attribute [name] for element [id]
	 * Returns true if any state is changed
	 */
	public inline function remove( name : String, id : TElementId ) : Bool {
		var a = t.get( name );
		if ( null == a )
			error( 'No attribute by the name ' + name );
		return a.v.remove( id );
	}
	
	/**
	 * Joins all attributes of elements [a] and [b] into element [c],
	 * reseting those of [a] and [b] to their defaults
	 */
	public inline function join( a : TElementId, b : TElementId, c : TElementId ) : Void {
		for ( n in t.keys() ) {
			var att = t.get( n );
			att.v.set( c, att.j( att.v.exists( c ) ? att.v.get( c ): att.d, att.j( att.v.exists( a ) ? att.v.get( a ): att.d, att.v.exists( b ) ? att.v.get( b ) : att.d ) ) );
			att.v.remove( a );
			att.v.remove( b );
		}
	}
	
	/**
	 * Error function that may be dynamically rebinded
	 */
	public dynamic function error( msg : String ) : Void {
		throw msg;
	}

	public function copyStructure(): ExtraAttributeTable<A> {
		var x = new ExtraAttributeTable<A>();
		for ( att in t.keys() ) {
			var def = t.get( att );
			x.attribute_add( att, def.d, def.j );
		}
		return x;
	}

	public function atts(): Iterable<String> {
		return { iterator: function () return t.keys() };
	}
	
}

/**
 * Element hash table, hashed by element internal id
 */
private typedef TElementIdHash<A> = IntHash<A>;

/**
 * Extra attribute definition
 * Contains the default value, the join function and the values other than the defualt
 */
private class ExtraAttributeDefinition<A> {
	public var v( default, null ) : TElementIdHash<A>;
	public var d( default, null ) : A;
	public var j( default, null ) : A -> A -> A;
	
	public function new( default_value, join ) {
		v = new TElementIdHash();
		d = default_value;
		j = join;
	}
}
