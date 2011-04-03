package R2::Web::Form::Participation;

use Moose;
use Chloro;

use namespace::autoclean;

use R2::Types qw( NonEmptyStr );

with 'R2::Role::Web::Form', 'R2::Role::Web::Form::StartAndEndDates';

field description => (
    isa => NonEmptyStr,
);

__PACKAGE__->meta()->make_immutable();

1;
