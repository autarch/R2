package R2::Role::Search::Plugin;

use Moose::Role;

use namespace::autoclean;

use R2::Types qw( NonEmptyStr );

requires qw( apply_where_clauses uri_parameters _build_description );

has search => (
    is       => 'ro',
    does     => 'R2::Role::Search',
    required => 1,
    weak_ref => 1,
);

has description => (
    is       => 'ro',
    does     => NonEmptyStr,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_description',
);

1;
