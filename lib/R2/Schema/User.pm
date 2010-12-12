package R2::Schema::User;

use strict;
use warnings;
use namespace::autoclean;

use Authen::Passphrase::BlowfishCrypt;
use DateTime::Locale;
use List::AllUtils qw( first );
use R2::Schema;
use R2::Schema::Contact;
use R2::Schema::EmailAddress;
use R2::Schema::Person;
use R2::Types qw( Str );
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator' =>
    { steps => [qw( _require_username_or_email )] };
with 'R2::Role::Schema::URIMaker';

has _dt_locale => (
    is       => 'ro',
    isa      => 'DateTime::Locale::Base',
    init_arg => undef,
    lazy     => 1,
    default  => sub { DateTime::Locale->load( $_[0]->locale_code() ) },
);

has date_format => (
    is       => 'ro',
    isa      => Str,
    init_arg => undef,
    lazy     => 1,
    default  => sub { $_[0]->_dt_locale()->date_format_medium() },
);

has time_format => (
    is       => 'ro',
    isa      => Str,
    init_arg => undef,
    lazy     => 1,
    default  => sub { $_[0]->_dt_locale()->time_format_medium() },
);

has datetime_format => (
    is       => 'ro',
    isa      => Str,
    init_arg => undef,
    lazy     => 1,
    default  => sub { $_[0]->_dt_locale()->datetime_format_medium() },
);

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('User') );

    has_one 'person' => (
        table   => $schema->table('Person'),
        handles => [
            grep { !__PACKAGE__->meta()->has_attribute($_) }
                grep { $_ ne 'person' }
                R2::Schema::Person->meta()->get_attribute_list(),
            R2::Schema::Contact->meta()->get_attribute_list(),
            qw( display_name ),
        ],
    );
}

my $UnusablePW = '*unusable*';

around 'insert' => sub {
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    if ( delete $p{disable_login} ) {
        $p{password} = $UnusablePW;
        $p{is_disabled} = 1;
    }
    elsif ( $p{password} ) {
        $p{password} = $class->_password_as_rfc2307( $p{password} );
    }

    my %user_p
        = map { $_ => delete $p{$_} }
        grep { $class->Table()->column($_) } keys %p;

    $user_p{username} ||= $p{email_address};

    my $email_address = delete $p{email_address};

    my $sub = sub {
        my $person = R2::Schema::Person->insert(%p);

        unless ( string_is_empty($email_address) ) {
            R2::Schema::EmailAddress->insert(
                email_address => $email_address,
                contact_id    => $person->person_id(),
                is_preferred  => 1,
            );
        }

        my $user = $class->$orig(
            %user_p,
            user_id  => $person->person_id(),
        );

        $user->_set_person($person);

        return $user;
    };

    return R2::Schema->RunInTransaction($sub);
};

around update => sub {
    my $orig = shift;
    my $self = shift;
    my %p    = @_;

    if ( delete $p{disable_login} ) {
        $p{password} = $UnusablePW;
        $p{is_disabled} = 1;
    }
    elsif ( !string_is_empty( $p{password} ) ) {
        $p{password} = $self->_password_as_rfc2307( $p{password} );
    }

    $p{last_modified_datetime} = Fey::Literal::Function->new('NOW');

    return $self->$orig(%p);
};

sub _require_username_or_email {
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return unless $is_insert;

    return {
        message => 'A user must have a username or email address.',
        field   => 'username',
        }
        if string_is_empty( $p->{username} )
            && string_is_empty( $p->{email_address} );

    return;
}

sub _password_as_rfc2307 {
    my $self = shift;
    my $pw   = shift;

    # XXX - require a certain length or complexity? make it
    # configurable?
    my $pass = Authen::Passphrase::BlowfishCrypt->new(
        cost        => 8,
        salt_random => 1,
        passphrase  => $pw,
    );

    return $pass->as_rfc2307();
}

sub check_password {
    my $self = shift;
    my $pw   = shift;

    my $pass = Authen::Passphrase::BlowfishCrypt->from_rfc2307(
        $self->password() );

    return $pass->match($pw);
}

sub format_date {
    my $self = shift;
    my $dt   = shift;

    return $dt->clone()->set_time_zone( $self->time_zone() )
        ->format_cldr( $self->date_format() );
}

sub format_datetime {
    my $self = shift;
    my $dt   = shift;

    return $dt->clone()->set_time_zone( $self->time_zone() )
        ->format_cldr( $self->datetime_format() );
}

sub _base_uri_path {
    my $self = shift;

    return '/user/' . $self->user_id();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
