package R2::Web::Form::User;

use Moose;
use Chloro;

use namespace::autoclean;

use List::AllUtils qw( all );
use R2::Types qw( Bool DatabaseId NonEmptyStr );
use R2::Util qw( string_is_empty );

with 'R2::Role::Web::Form';

with 'R2::Role::Web::Form::FromSchema' => {
    classes => ['R2::Schema::User'],
    skip    => [
        'account_id',
        'creation_datetime',
        'is_system_admin',
        'last_modified_datetime',
        'password',
    ],
};

field password => (
    isa    => NonEmptyStr,
    secure => 1,
);

field password2 => (
    isa    => NonEmptyStr,
    secure => 1,
);

field first_name => (
    isa      => NonEmptyStr,
    required => 1,
);

field last_name => (
    isa      => NonEmptyStr,
    required => 1,
);

field is_system_admin => (
    isa       => Bool,
    extractor => '_extract_is_system_admin',
);

sub _extract_is_system_admin {
    my $self = shift;

    return unless $self->user()->is_system_admin();

    return $self->_extract_field_value(@_);
}

sub _validate_form {
    my $self    = shift;
    my $params  = shift;
    my $results = shift;

    my $pw1 = $results->{password}  ? $results->{password}->value()  : q{};
    my $pw2 = $results->{password2} ? $results->{password2}->value() : q{};

    return if all { string_is_empty($_) } $pw1, $pw2;

    {
        no warnings 'uninitialized';
        return 'The two passwords you provided did not match.'
            unless $pw1 eq $pw2;
    }

    return;
}

__PACKAGE__->meta()->make_immutable();

1;
