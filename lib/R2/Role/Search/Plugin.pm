package R2::Role::Search::Plugin;

use Moose::Role;

use namespace::autoclean;

requires qw( apply_where_clauses uri_parameters );

has search => (
    is       => 'ro',
    does     => 'R2::Role::Search',
    required => 1,
    weak_ref => 1,
);

1;
