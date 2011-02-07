package R2::Role::Context::Sidebar;

use Moose::Role;

use namespace::autoclean;

use R2::Web::Sidebar;

has sidebar => (
    is       => 'ro',
    isa      => 'R2::Web::Sidebar',
    lazy     => 1,
    default  => sub { R2::Web::Sidebar->new() },
    init_arg => undef,
);

1;

# ABSTRACT: Adds a sidebar attribute to the Catalyst object
