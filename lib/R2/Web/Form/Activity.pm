package R2::Web::Form::Activity;

use Moose;
use Chloro;

use namespace::autoclean;

use R2::Types qw( Bool DatabaseId Str );

with 'R2::Role::Web::Form';

field name => (
    isa      => Str,
    required => 1,
);

field activity_type_id => (
    isa      => DatabaseId,
    required => 1,
);

field is_archived => (
    isa     => Bool,
    default => 0,
);

__PACKAGE__->meta()->make_immutable();

1;
