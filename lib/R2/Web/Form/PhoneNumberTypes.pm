package R2::Web::Form::PhoneNumberTypes;

use Moose;
use Chloro;

use namespace::autoclean;

use Moose::Meta::Class;
use R2::Role::Web::ResultSet::NewAndExistingGroups;
use R2::Types qw( Bool NonEmptyStr );

with 'R2::Role::Web::Form';

group phone_number_type => (
    repetition_field => 'phone_number_type_id',
    (
        field name => (
            isa      => NonEmptyStr,
            required => 1,
        )
    ),
    (
        field applies_to_person => (
            isa      => Bool,
            required => 1,
        )
    ),
    (
        field applies_to_household => (
            isa      => Bool,
            required => 1,
        )
    ),
    (
        field applies_to_organization => (
            isa      => Bool,
            required => 1,
        )
    ),
);

my $Class = Moose::Meta::Class->create_anon_class(
    superclasses => ['Chloro::ResultSet'],
    roles        => [
        R2::Role::Web::ResultSet::NewAndExistingGroups->meta()
            ->generate_role( parameters => { group => 'phone_number_type' } )
    ],
    cache => 1,
);

$Class->make_immutable();

sub _resultset_class { $Class->name() }

__PACKAGE__->meta()->make_immutable();

1;