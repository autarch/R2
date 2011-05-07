package R2::Web::Form::Participation;

use Moose;
use Chloro;

use namespace::autoclean;

use R2::Types qw( NonEmptyStr );

with 'R2::Role::Web::Form', 'R2::Role::Web::Form::StartAndEndDates';

with 'R2::Role::Web::Form::FromSchema' => {
    classes => ['R2::Schema::ContactParticipation'],
    skip    => [ 'activity_id', 'contact_id', 'participation_type_id' ],
};

__PACKAGE__->meta()->make_immutable();

1;
