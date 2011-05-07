package R2::Web::Form::PaymentTypes;

use namespace::autoclean;

use Moose;
use Chloro;

use Moose::Meta::Class;
use R2::Role::Web::ResultSet::NewAndExistingGroups;

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Group::FromSchema' => {
    group   => 'payment_type',
    classes => ['R2::Schema::PaymentType'],
    skip    => [ 'account_id', 'display_order' ],
};

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
