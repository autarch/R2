package R2::Web::Tab;

use strict;
use warnings;
use namespace::autoclean;

use Moose;
use MooseX::StrictConstructor;

has 'uri' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'label' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'tooltip' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'is_selected' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

__PACKAGE__->meta()->make_immutable();
1;
