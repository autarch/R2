package R2::Web::Form::PaymentTypes;

use Moose;
use Chloro;

use namespace::autoclean;

use Moose::Meta::Class;
use R2::Role::Web::ResultSet::NewAndExistingGroups;
use R2::Types qw( NonEmptyStr );

with 'R2::Role::Web::Form';

group payment_type => (
    repetition_key => 'payment_type_id',
    (
        field name => (
            isa      => NonEmptyStr,
            required => 1,
        )
    )
);

{
    my $Class = Moose::Meta::Class->create_anon_class(
        superclasses => ['Chloro::ResultSet'],
        roles        => [
            R2::Role::Web::ResultSet::NewAndExistingGroups->meta()
                ->generate_role( parameters => { group => 'payment_type' } )
        ],
        weaken => 0,
    );

    $Class->make_immutable();

    sub _resultset_class { $Class->name() }
}

__PACKAGE__->meta()->make_immutable();

1;
