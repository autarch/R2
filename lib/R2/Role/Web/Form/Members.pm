package R2::Role::Web::Form::Members;

use Moose::Role;
use Chloro;

use R2::Types qw( NonEmptyStr );

group member => (
    repetition_key   => 'person_id',
    is_empty_checker => '_member_is_empty',
    (
        field position => (
            isa => NonEmptyStr,
        )
    ),
);

# Just the presence of a person_id indicates the group is not empty
sub _member_is_empty {0}

1;
