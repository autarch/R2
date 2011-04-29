package R2::Web::Form::EmailAddresses;

use Moose;
use Chloro;

use R2::Role::Web::ResultSet::NewAndExistingGroups;
use R2::Schema;
use R2::Types qw( Bool );

with qw(
    R2::Role::Web::Form
    R2::Role::Web::Form::EmailAddressGroup
);

{
    my $Class = Moose::Meta::Class->create_anon_class(
        superclasses => ['Chloro::ResultSet'],
        roles        => [
            map {
                R2::Role::Web::ResultSet::NewAndExistingGroups->meta()
                    ->generate_role( parameters => { group => $_ } )
                } qw( email_address )
        ],
        cache => 1,
    );

    $Class->make_immutable();

    sub _resultset_class { $Class->name() }
}

1;

