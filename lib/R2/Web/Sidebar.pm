package R2::Web::Sidebar;

use Moose;

use namespace::autoclean;

use R2::Types qw( ArrayRef Str );

use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has _sidebar => (
    traits   => ['Array'],
    isa      => ArrayRef [Str],
    lazy     => 1,
    default  => sub { [] },
    init_arg => undef,
    handles  => {
        add_item  => 'push',
        has_items => 'count',
        items     => 'elements',
    },
);

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: A collection of sidebar items in the web UI
