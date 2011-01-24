package R2::AppRole::Tabs;

use strict;
use warnings;
use namespace::autoclean;

use Scalar::Util qw( blessed );
use R2::Web::Tab;
use Tie::IxHash;

use Moose::Role;

has _tabs => (
    is       => 'ro',
    isa      => 'Tie::IxHash',
    lazy     => 1,
    default  => sub { Tie::IxHash->new() },
    init_arg => undef,
    handles  => {
        tabs      => 'Values',
        _add_tab  => 'Push',
        tab_by_id => 'FETCH',
        has_tabs  => 'Length',
    },
);

sub add_tab {
    my $self = shift;
    my $tab  = shift;

    $tab = R2::Web::Tab->new( %{$tab} )
        unless blessed $tab;

    $self->_add_tab( $tab->id() => $tab );
}

1;

# ABSTRACT: Adds tab-related methods to the Catalyst object
