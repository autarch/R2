package R2::Role::Web::Form::AddressGroup;

use Moose::Role;
use Chloro;

use R2::Types qw( DatabaseId NonEmptyStr );
use R2::Util qw( string_is_empty );

group address => (
    repetition_key   => 'address_id',
    is_empty_checker => '_address_is_empty',
    (
        field address_type_id => (
            isa      => DatabaseId,
            required => 1,
        ),
    ),
    (
        field street_1 => (
            isa => NonEmptyStr,
        ),
    ),
    (
        field street_2 => (
            isa => NonEmptyStr,
        ),
    ),
    (
        field city => (
            isa => NonEmptyStr,
        ),
    ),
    (
        field region => (
            human_name => 'State/Region',
            isa        => NonEmptyStr,
        ),
    ),
    (
        field postal_code => (
            isa => NonEmptyStr,
        ),
    ),
    (
        field country => (
            isa => NonEmptyStr,
        ),
    ),
    (
        field note => (
            isa => NonEmptyStr,
        ),
    ),
);

field address_is_preferred => (
    isa      => NonEmptyStr,
    required => 1,
);

sub _address_is_empty {
    my $self   = shift;
    my $params = shift;
    my $prefix = shift;
    my $group  = shift;

    my @keys = map { join q{.}, $prefix, $_->name() } $group->fields();

    return 1 unless ( grep { !string_is_empty( $params->{$_} ) } @keys ) > 1;
}

1;
