package R2::Web::Form::Donation;

use Moose;
use Chloro;

use R2::Schema;
use R2::Types qw( Str );

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Form::FromFey' => {
    table => R2::Schema->Schema->table('Donation'),
    skip  => [qw( contact_id dedicated_to_contact_id )],
};

field dedicated_to => (
    isa => Str,
);

1;

