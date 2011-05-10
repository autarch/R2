package R2::Web::Form::Donation;

use Moose;
use Chloro;

use R2::Schema;
use R2::Types qw( Str );

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Form::FromSchema' => {
    classes => ['R2::Schema::Donation'],
    skip    => [qw( contact_id )],
};

1;

