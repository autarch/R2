package R2::Role::Web::Form::EmailAddressGroup;

use Moose::Role;
use Chloro;

use R2::Types qw( Bool NonEmptyStr );

with 'R2::Role::Web::Group::FromSchema' => {
    group   => 'email_address',
    classes => ['R2::Schema::EmailAddress'],
    skip    => [ 'contact_id', 'is_preferred' ],
};

field allows_email => (
    isa     => Bool,
    default => 1,
);

1;
