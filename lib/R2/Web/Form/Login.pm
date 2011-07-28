package R2::Web::Form::Login;

use Moose;
use Chloro;

use namespace::autoclean;

use List::AllUtils qw( any );
use R2::Schema::User;
use R2::Types qw( Bool NonEmptyStr Str );
use R2::Util qw( string_is_empty );

field username => (
    isa      => NonEmptyStr,
    required => 1,
);

field password => (
    isa      => NonEmptyStr,
    required => 1,
    secure   => 1,
);

field remember => (
    isa     => Bool,
    default => 0,
);

field return_to => (
    isa     => Str,
    default => q{},
);

sub _validate_form {
    my $self    = shift;
    my $params  = shift;
    my $results = shift;

    return
        if any { string_is_empty($_) } $results->{username}->value(),
        $results->{password}->value();

    my $user
        = R2::Schema::User->new( username => $results->{username}->value() );

    return 'The username or password you provided was not valid.'
        unless $user
            && $user->check_password( $results->{password}->value() );

    return;
}

sub _make_resultset {
    my $self        = shift;
    my $params      = shift;
    my $results     = shift;
    my $form_errors = shift;

    my $user
        = R2::Schema::User->new( username => $results->{username}->value() );

    return R2::Web::ResultSet::WithUser->new(
        params      => $params,
        results     => $results,
        form_errors => $form_errors,
        ( $user ? ( user => $user ) : () ),
    );
}

{
    package # hide from PAUSE
        R2::Web::ResultSet::WithUser;

    use Moose;

    extends 'Chloro::ResultSet';

    has user => (
        is  => 'ro',
        isa => 'R2::Schema::User',
    );
}

__PACKAGE__->meta()->make_immutable();

1;
