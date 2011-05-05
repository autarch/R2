package R2::Role::Web::Form::PhoneNumberGroup;

use Moose::Role;
use Chloro;

use R2::Types qw( Bool DatabaseId NonEmptyStr );
use R2::Util qw( string_is_empty );

with 'R2::Role::Web::Group::FromSchema' => {
    group            => 'phone_number',
    is_empty_checker => '_phone_number_is_empty',
    classes          => ['R2::Schema::PhoneNumber'],
    skip             => [ 'contact_id', 'creation_datetime', 'is_preferred' ],
};

sub _phone_number_is_empty {
    my $self   = shift;
    my $params = shift;
    my $prefix = shift;
    my $group  = shift;

    my @keys = map { join q{.}, $prefix, $_->name() } $group->fields();

    return 1 unless ( grep { !string_is_empty( $params->{$_} ) } @keys ) > 2;
    return 0;
}

1;
