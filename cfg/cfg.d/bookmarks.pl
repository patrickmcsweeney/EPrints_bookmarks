$c->{datasets}->{bookmark} = {
        name => "bookmark", # name
        type => "Bookmark", # data object class
        sqlname => "bookmark", # database table name
 };

{

package EPrints::DataObj::Bookmark;

use EPrints;
use strict;

our @ISA = ( 'EPrints::DataObj' );

sub get_system_field_info
{
	my( $class ) = @_;
	
	return 
	( 
		{ name=>"bookmarkid", type=>"counter", required=>1, show_in_html=>0, can_clone=>0, sql_counter=>"bookmarkid" },

		{ name=>"userid", type=>"itemref", required=>1, show_in_html=>0, can_clone=>0, datasetid=>"user"},

		{ name=>"eprintid", type=>"itemref", required=>1, show_in_html=>0, can_clone=>0, datasetid=>"eprint"},

		{ name=>"datestamp", type=>"time", required=>0, import=>0,
                	render_res=>"minute", render_style=>"short", can_clone=>0 },

	);
}

#sub get_defaults
#{
#	my( $class, $session, $data ) = @_;
#
#	if( !defined $data->{sneepid} )
#	{ 
#		my $new_id = $session->get_database->counter_next( "sneepid" );
#		$data->{sneepid} = $new_id;
#	}
#
#	return $data;
#}

sub get_dataset_id
{
	return "sneep";
}

}

