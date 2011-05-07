package R2::Web::Form::CustomFields;

use namespace::autoclean;

use Moose;
use Chloro;

use Moose::Meta::Class;
use R2::Role::Web::ResultSet::NewAndExistingGroups;
use R2::Util qw( string_is_empty );

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Group::FromSchema' => {
    group            => 'custom_field',
    is_empty_checker => '_custom_field_is_empty',
    classes          => ['R2::Schema::CustomField'],
    skip => [ 'account_id', 'custom_field_group_id', 'display_order', 'html_widget_id' ],
};

sub _custom_field_is_empty {
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
