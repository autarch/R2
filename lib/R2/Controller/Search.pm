package R2::Controller::Search;

use strict;
use warnings;
use namespace::autoclean;

use R2::Search::Contact;

use Moose;
use CatalystX::Routes;

BEGIN { extends 'R2::Controller::Base' }

get 'search/contact'
    => chained '/account/_set_account'
    => args 0
    => sub {
    my $self = shift;
    my $c    = shift;

    $c->stash()->{search} = R2::Search::Contact->new(
        account => $c->account(),
        limit   => 20,
        page    => 1,
    );

    $c->stash()->{template} = '/search/contact_list';
};

__PACKAGE__->meta()->make_immutable();

1;
