package R2::Role::Web::Form::AddressGroup;

use Moose::Role;
use Chloro;

use R2::Types qw( DatabaseId NonEmptyStr );
use R2::Util qw( string_is_empty );

with 'R2::Role::Web::Group::FromSchema' => {
    group            => 'address',
    is_empty_checker => '_address_is_empty',
    classes          => ['R2::Schema::Address'],
    skip             => [ 'contact_id', 'creation_datetime', 'is_preferred' ],
};

sub _address_is_empty {
    my $self   = shift;
    my $params = shift;
    my $prefix = shift;
    my $group  = shift;

    my @keys = map { join q{.}, $prefix, $_->name() } $group->fields();

    return 1 unless ( grep { !string_is_empty( $params->{$_} ) } @keys ) > 1;
    return 0;
}

1;
