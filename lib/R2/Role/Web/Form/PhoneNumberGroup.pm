package R2::Role::Web::Form::PhoneNumberGroup;

use Moose::Role;
use Chloro;

use R2::Types qw( Bool DatabaseId NonEmptyStr );
use R2::Util qw( string_is_empty );

group phone_number => (
    repetition_key   => 'phone_number_id',
    is_empty_checker => '_phone_number_is_empty',
    (
        field phone_number_type_id => (
            isa      => DatabaseId,
            required => 1,
        ),
    ),
    (
        field phone_number => (
            isa      => NonEmptyStr,
            required => 1,
        ),
    ),
    (
        field allows_sms => (
            isa     => Bool,
            default => 0,
        ),
    ),
    (
        field note => (
            isa => NonEmptyStr,
        ),
    )
);

field phone_number_is_preferred => (
    isa      => NonEmptyStr,
    required => 1,
);

sub _phone_number_is_empty {
    my $self   = shift;
    my $params = shift;
    my $prefix = shift;
    my $group  = shift;

    my @keys = map { join q{.}, $prefix, $_->name() } $group->fields();

    return 1 unless ( grep { !string_is_empty( $params->{$_} ) } @keys ) > 1;
}

1;
