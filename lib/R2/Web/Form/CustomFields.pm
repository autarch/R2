package R2::Web::Form::CustomFields;

use Moose;
use Chloro;

use namespace::autoclean;

use Moose::Meta::Class;
use R2::Role::Web::ResultSet::NewAndExistingGroups;
use R2::Types qw( Bool NonEmptyStr );
use R2::Util qw( string_is_empty );

with 'R2::Role::Web::Form';

group custom_field => (
    repetition_key   => 'custom_field_id',
    is_empty_checker => '_group_is_empty',
    (
        field label => (
            isa      => NonEmptyStr,
            required => 1,
        )
    ),
    (
        field description => (
            isa => NonEmptyStr,
        )
    ),
    (
        field type => (
            isa      => NonEmptyStr,
            required => 1,
        )
    ),
    (
        field is_required => (
            isa     => Bool,
            default => 0,
        )
    ),
);

sub _group_is_empty {
    my $self   = shift;
    my $params = shift;
    my $prefix = shift;
    my $group  = shift;

    my $key = join q{.}, $prefix, 'label';

    return string_is_empty( $params->{$key} );
}

{
    my $Class = Moose::Meta::Class->create_anon_class(
        superclasses => ['Chloro::ResultSet'],
        roles        => [
            R2::Role::Web::ResultSet::NewAndExistingGroups->meta()
                ->generate_role( parameters => { group => 'custom_field' } )
        ],
        weaken => 0,
    );

    $Class->make_immutable();

    sub _resultset_class { $Class->name() }
}

__PACKAGE__->meta()->make_immutable();

1;
