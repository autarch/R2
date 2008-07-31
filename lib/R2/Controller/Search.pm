package R2::Controller::Search;

use strict;
use warnings;

use base 'R2::Controller::Base';

use R2::Search::Contact;


sub contact : Local
{
    my $self = shift;
    my $c    = shift;

    $c->stash()->{search} =
        R2::Search::Contact->new( account => $c->user()->account(),
                                  limit   => 20,
                                  page    => 1,
                                );

    $c->stash()->{template} = '/search/contact_list';
}

1;
