package EPrints::Plugin::Screen::Bookmarks;

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
	
	my $eprintid = $repo->param("eprintid") || $self->{processor}->{eprint}->id();
	
	if( $self->is_bookmarked( $eprintid ) )
	{
		return 0;
	}

	return 1;
}

sub action_add
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	if( $self->is_bookmarked( $repo->param("eprintid") ) )
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
	my $repo = $self->{repository};

        if(!defined $repo->current_user)
        {
                return 0;
        }
#{ meta_fields => [ 'item_issues_count' ], value => '1-', describe=>1 }
	return $self->is_bookmarked($self->{processor}->{eprint}->id());
}

sub action_remove
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $eprint = $repo->eprint($repo->param("eprintid"));

	my $list = $repo->dataset("bookmark")->search(
		filters=>[
			{meta_fields=>['userid'], value=>$repo->current_user->id()},
			{meta_fields=>['eprintid'], value=>$eprint->id()},
		],
		satisfy_all=>1
	);

	$list->map(sub {
		my ( $repo, $dataset, $bookmark ) = @_;
		$bookmark->delete();
	});

	if( $eprint->get_value( 'eprint_status' ) eq 'archive' )
	{
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

	my $repo = $self->{repository};

	my $list = $repo->dataset("bookmark")->search(
		filters=>[
			{meta_fields=>['userid'], value=>$repo->current_user->id()},
		]
	);

	$list->map(sub {
		my ( $repo, $dataset, $bookmark ) = @_;
		$bookmark->delete();
	});
}

sub is_bookmarked
{
	my ( $self, $eprintid ) = @_;
	
	my $repo = $self->{repository};

	my $list = $repo->dataset("bookmark")->search(
                filters=>[
                        {meta_fields=>['userid'], value=>$repo->current_user->id()},
                        {meta_fields=>['eprintid'], value=>$eprintid},
                ],
		satisfy_all=>1
        );

	print STDERR "is bookmarked eprintid = $eprintid and trouble ".$self->{processor}->{eprint}->id()." list count ".$list->count()."\n\n";
	
        return $list->count()
}

sub _render_list
{
	my( $self ) = @_;

	my $repo = $self->{repository};

	my $list = $repo->dataset("bookmark")->search(
		filters=>[
			{meta_fields=>['userid'], value=>$repo->current_user->id()},
		]
	);

	my $frag = $repo->make_element( 'div', style => 'text-align: center;' );
	if($list->count == 0)
	{
        	$frag->appendChild( $self->html_phrase( 'no_bookmarks' ) );
		return $frag;
	}

	my $bookmark_table = $repo->make_element( 'table', style => 'margin: auto;' );
	$list->map(sub {
		my ( $repo, $dataset, $bookmark ) = @_;

		my $eprint = $repo->eprint( $bookmark->value("eprintid") );

		if( !defined $eprint )
		{
			return;
		}

		my $bookmark_row = $repo->make_element( 'tr' );
		my $bookmark_title_cell = $repo->make_element( 'td' );
		my $bookmark_delete_cell = $repo->make_element( 'td' );
		
#		my $bookmark_title_link = $repo->make_element( 'a', href => $eprint->get_url );
#		$bookmark_title_link->appendChild( $repo->make_text( $eprint->get_value( 'title' ) ) );
#		$bookmark_title_cell->appendChild( $bookmark_title_link );

		$bookmark_title_cell->appendChild( $eprint->render_citation( "bookmark" ));
		$bookmark_row->appendChild( $bookmark_title_cell );
		
		my %remove_bookmark_buttons = (
			'remove' => $self->phrase( 'remove_bookmark' ),
		);
		my $remove_bookmark_form = $repo->render_input_form(
			buttons => \%remove_bookmark_buttons,
			hidden_fields => {
				screen => $self->{processor}->{screenid},
				eprintid => $eprint->get_id,
			},
		);
		$bookmark_delete_cell->appendChild( $remove_bookmark_form );
		$bookmark_row->appendChild( $bookmark_delete_cell );
		
		$bookmark_table->appendChild( $bookmark_row );
	
	});

	my $bookmarks_table_div = $repo->make_element( 'div', class => 'ep_block' );
	$bookmarks_table_div->appendChild( $bookmark_table );
	$frag->appendChild( $bookmarks_table_div );
	
	my %buttons = (
		'clear' => $self->phrase( 'clear_bookmarks' ),
	);

	my $form = $repo->render_input_form(
		buttons => \%buttons,
		hidden_fields => {
			screen => $self->{processor}->{screenid},
		},
	);

	my $buttons_div = $repo->make_element( 'div', class => 'ep_block', style => 'margin: 10px' );
	$buttons_div->appendChild( $form );

	$frag->appendChild( $buttons_div );

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

sub properties_from
{
        my( $self ) = @_;

        $self->{processor}->{eprintid} = $self->{session}->param( "eprintid" );
        unless (defined $self->{processor}->{required_fields_only}) {
                $self->{processor}->{required_fields_only} = $self->{session}->param( "required_only" );
        }
        $self->{processor}->{eprint} = new EPrints::DataObj::EPrint( $self->{session}, $self->{processor}->{eprintid} );

        $self->SUPER::properties_from;
}


1;
