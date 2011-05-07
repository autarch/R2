package R2::Web::Form::DonationSources;

use namespace::autoclean;

use Moose;
use Chloro;

use Moose::Meta::Class;
use R2::Role::Web::ResultSet::NewAndExistingGroups;

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Group::FromSchema' => {
    group   => 'donation_source',
    classes => ['R2::Schema::DonationSource'],
    skip    => [ 'account_id', 'display_order' ],
};

{
    my $Class = Moose::Meta::Class->create_anon_class(
        superclasses => ['Chloro::ResultSet'],
        roles        => [
            R2::Role::Web::ResultSet::NewAndExistingGroups->meta()
                ->generate_role(
                parameters => { group => 'donation_source' }
                )
        ],
        weaken => 0,
    );

    $Class->make_immutable();

    sub _resultset_class { $Class->name() }
}

__PACKAGE__->meta()->make_immutable();

1;
