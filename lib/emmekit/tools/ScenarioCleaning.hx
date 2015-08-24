package emmekit.tools;

private typedef ScenarioCleaningFilter = Node -> Bool;

class ScenarioCleaning {

	/**
	 * Generic network cleaning
	 */
	public static function scenario_cleaning( s : Scenario, filter : ScenarioCleaningFilter ) : Void {
		// TODO change the order in which nodes are checked, so that alternate simple paths are resolved
		// in the most (or close to) elegant way possible
		for ( n in s.node_iterator() )
			if ( filter( n ) )
				n.delete_after_joining();
	}

	/**
	 * Simple cosmetic points removal, with the following filter:
	 * !centroid && !start_of_route && !end_of_route
	 */
	public static function clean1( s : Scenario, ?additional_filters : ScenarioCleaningFilter ) : Void {
		var segment_filter = function( seg : Segment ) { return 0 == seg.pos || seg.line.segment_count() - 1 == seg.pos || seg.line.segment_at( seg.pos + 1 ).node == seg.line.segment_at( seg.pos - 1 ).node; };
		if ( null == additional_filters )
			scenario_cleaning( s, function( n : Node ) {
				var spread = n.neighbors();
				return
					!n.is_zone &&
					0 == n.segment_filter( segment_filter ).length &&
					2 == spread.length &&
					n.link_from_count() == n.link_to_count() &&
					( 1 == n.link_from_count() || 2 == n.link_from_count() )
				;
			} );
		else
			scenario_cleaning( s, function( n : Node ) {
				var spread = n.neighbors();
				return
					!n.is_zone &&
					0 == n.segment_filter( segment_filter ).length &&
					2 == spread.length &&
					n.link_from_count() == n.link_to_count() &&
					( 1 == n.link_from_count() || 2 == n.link_from_count() )
					&& additional_filters( n )
				;
			} );
	}

}
