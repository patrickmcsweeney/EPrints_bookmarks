package EPrints::Plugin::Screen::User::Bookmarks;

use EPrints::Plugin::Screen;

@ISA = ( 'EPrints::Plugin::Screen' );

use strict;

sub new
{
	my( $class, %params ) = @_;

	my $self = $class->SUPER::new( %params );

	$self->{actions} = [qw/ add remove clear /];

	$self->{appears} = [
		{
			place => 'key_tools',
			position => 250,
		},
	];

	return $self;
}

sub can_be_viewed
{
        my( $self ) = @_;

        return defined $self->{session}->current_user;
}

sub render
{
	my( $self ) = @_;

	my $session = $self->{session};

	my $frag = $session->make_doc_fragment;

	my $eprintid = $session->param( 'eprintid' );
	if( defined $eprintid )
	{
		$frag->appendChild( $self->_render_manage( $eprintid ) );
	}
	else
	{
		$frag->appendChild( $self->_render_list );
	}

	return $frag;
}

sub allow_add
{
	my( $self ) = @_;

	my $repo = $self->{repository};

        if(!defined $repo->current_user)
        {
                return 0;
        }

	if( is_bookmarked( $repo->param("eprintid" ) )
	{
		return 0;
	}

	return 1;
}

sub action_add
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	if(is_bookmarked($repo->param("eprintid"))
	{
		return;
	}

	$repo->dataset("bookmark")->create_dataobj({
		eprintid=>$repo->param("eprintid"),
		userid=>$repo->current_user->id(),
		datestamp=>EPrints::Time::get_iso_timestamp(),
	});	
}

sub allow_remove
{
	my( $self ) = @_;

	my $allow_remove = 1;
	my $session = $self->{session};

        if(!defined $session->current_user)
        {
                return 0;
        }

	my $bookmarks = EPrints::Plugin::Bookmarks::load_bookmarks( $session, $session->current_user );
	my $eprint = EPrints::DataObj::EPrint->new( $session, $session->param( 'eprintid' ) );
	$allow_remove = 0 unless( defined $bookmarks and defined $eprint );
	$allow_remove = 0 unless( $bookmarks->bookmarked( $eprint->get_id ) );

	return $allow_remove;
}

sub action_remove
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $bookmarks = EPrints::Plugin::Bookmarks::load_bookmarks( $session, $session->current_user );
	my $eprint = EPrints::DataObj::EPrint->new( $session, $session->param( 'eprintid' ) );
	
	return unless( defined $bookmarks and defined $eprint );

	if( $eprint->get_value( 'eprint_status' ) eq 'archive' )
	{
		$bookmarks->remove_from_bookmarks( $eprint->get_id );
		$self->{processor}->{redirect} = $eprint->get_url;
	}
}

sub allow_clear
{
	my( $self ) = @_;

	my $session = $self->{session};

        if(!defined $session->current_user)
        {
                return 0;
        }

	return 1;
}

sub action_clear
{
	my( $self ) = @_;

	my $session = $self->{session};
	my $bookmarks = EPrints::Plugin::Bookmarks::load_bookmarks( $session, $session->current_user );
	if( defined $bookmarks )
	{
		$bookmarks->remove;
	}
}

sub _render_list
{
	my( $self ) = @_;
	
	my $session = $self->{session};
	my $bookmarks = EPrints::Plugin::Bookmarks::load_bookmarks( $session, $session->current_user );
	my $frag = $session->make_element( 'div', style => 'text-align: center;' );
        my $r = $bookmarks->get_relation_ids;
        if( scalar @$r )
        {
		my $bookmark_table = $session->make_element( 'table', style => 'margin: auto;' );
		for( @$r )
		{
			my $eprint = EPrints::DataObj::EPrint->new( $session, $_ );
			if( defined $eprint )
			{
				my $bookmark_row = $session->make_element( 'tr' );
				my $bookmark_title_cell = $session->make_element( 'td' );
				my $bookmark_delete_cell = $session->make_element( 'td' );
				
				my $bookmark_title_link = $session->make_element( 'a', href => $eprint->get_url );
				$bookmark_title_link->appendChild( $session->make_text( $eprint->get_value( 'title' ) ) );
				$bookmark_title_cell->appendChild( $bookmark_title_link );
				$bookmark_row->appendChild( $bookmark_title_cell );
				
				my %remove_bookmark_buttons = (
					'remove' => $self->phrase( 'remove_bookmark' ),
				);
				my $remove_bookmark_form = $session->render_input_form(
					buttons => \%remove_bookmark_buttons,
					hidden_fields => {
						screen => $self->{processor}->{screenid},
						eprintid => $eprint->get_id,
					},
				);
				$bookmark_delete_cell->appendChild( $remove_bookmark_form );
				$bookmark_row->appendChild( $bookmark_delete_cell );
				
				$bookmark_table->appendChild( $bookmark_row );
			}
		}
		my $bookmarks_table_div = $session->make_element( 'div', class => 'ep_block' );
		$bookmarks_table_div->appendChild( $bookmark_table );
		$frag->appendChild( $bookmarks_table_div );
		
		my %buttons = (
			'clear' => $self->phrase( 'clear_bookmarks' ),
		);
	
		my $form = $session->render_input_form(
                	buttons => \%buttons,
                	hidden_fields => {
                	       	screen => $self->{processor}->{screenid},
                	},
        	);

		my $buttons_div = $session->make_element( 'div', class => 'ep_block', style => 'margin: 10px' );
		$buttons_div->appendChild( $form );

		$frag->appendChild( $buttons_div );
        }
        else
        {
                $frag->appendChild( $self->html_phrase( 'no_bookmarks' ) );
        }

        return $frag;
}

sub _render_manage
{
	my( $self, $eprintid ) = @_;
	
	my $session = $self->{session};
	my $bookmarks = EPrints::Plugin::Bookmarks::load_bookmarks( $session, $session->current_user );
	my $frag = $session->make_element( 'div', style => 'text-align: center;' );
	my $eprint = EPrints::DataObj::EPrint->new( $session, $eprintid );
	if( defined $eprint )
	{
		my $title = $session->make_element( 'h2' );
		$title->appendChild( $self->html_phrase( 'manage_bookmark', eprint_title => $session->make_text( $eprint->get_value( 'title' ) ) ) );
		$frag->appendChild( $title );
	
		my $description = $session->make_element( 'p' );
	
		my %buttons;
		if( !$bookmarks->bookmarked( $eprint->get_id ) )
		{
			%buttons = (
				'add' => $self->phrase( 'add_to_bookmarks' ),
			);
			$description->appendChild( $self->html_phrase( 'add_to_bookmarks_description', eprint_title => $session->make_text( $eprint->get_value( 'title' ) ) ) );	
		}
		else
		{
			%buttons = (
				'remove' => $self->phrase( 'remove_from_bookmarks' ),
			);
			$description->appendChild( $self->html_phrase( 'remove_from_bookmarks_description', eprint_title => $session->make_text( $eprint->get_value( 'title' ) ) ) );
		}

		my $form = $session->render_input_form(
                	buttons => \%buttons,
                	hidden_fields => {
                	       	screen => $self->{processor}->{screenid},
				eprintid => $eprint->get_id,
                	},
        	);

		$frag->appendChild( $description );
		$frag->appendChild( $form );
	}
	else
	{
		$frag->appendChild( $self->html_phrase( 'no_eprint', { eprintid => $eprintid } ) );
	}

	return $frag;
}
1;
