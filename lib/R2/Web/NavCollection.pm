package R2::Web::NavCollection;

use strict;
use warnings;
use namespace::autoclean;

use R2::Web::NavItem;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has _nav_items => (
    is       => 'ro',
    isa      => 'Tie::IxHash',
    lazy     => 1,
    default  => sub { Tie::IxHash->new() },
    init_arg => undef,
    handles  => {
        items     => 'Values',
        _add_item => 'Push',
        by_id     => 'FETCH',
        has_items => 'Length',
    },
);

sub add_item {
    my $self     = shift;
    my $nav_item = shift;

    $nav_item = R2::Web::NavItem->new( %{$nav_item} )
        unless blessed $nav_item;

    $self->_add_item( $nav_item->id() => $nav_item );
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: A collection of nav items in the web UI
