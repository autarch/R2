package R2::AppRole::NavCollections;

use strict;
use warnings;
use namespace::autoclean;

use Scalar::Util qw( blessed );
use R2::Web::NavCollection;
use Tie::IxHash;

use Moose::Role;

has tabs => (
    is       => 'ro',
    isa      => 'R2::Web::NavCollection',
    lazy     => 1,
    default  => sub { R2::Web::NavCollection->new() },
    init_arg => undef,
);

has local_nav => (
    is       => 'ro',
    isa      => 'R2::Web::NavCollection',
    lazy     => 1,
    default  => sub { R2::Web::NavCollection->new() },
    init_arg => undef,
);

1;

# ABSTRACT: Adds tab-related methods to the Catalyst object
