package R2::Role::Web::Form::ContactNote;

use Moose::Role;
use Chloro;

use R2::Types qw( NonEmptyStr );

field note => (
    isa => NonEmptyStr,
);

1;
