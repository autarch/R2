package R2::Schema::User;

use strict;
use warnings;
use namespace::autoclean;

use Authen::Passphrase::BlowfishCrypt;
use DateTime::Locale;
use Email::Valid;
use List::AllUtils qw( first );
use MooseX::Params::Validate qw( validated_list );
use R2::Schema;
use R2::Schema::Contact;
use R2::Schema::EmailAddress;
use R2::Schema::Person;
use R2::Types qw( ContactLike HashRef Str );
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::Schema::DataValidator' =>
    { steps => [qw( _require_username_or_email )] };
with 'R2::Role::URIMaker';

{
    my %formats = (
        American => [ 'MMM d, yyyy', 'MMM d' ],
        European => [ 'd MMM yyyy', 'd MMM' ],
        YMD      => [ 'yyyy-MM-dd',  'MM-dd' ],
    );

    has date_format => (
        is       => 'ro',
        isa      => Str,
        init_arg => undef,
        lazy     => 1,
        default  => sub { $formats{ $_[0]->date_style() }[0] },
    );

    has date_format_without_year => (
        is       => 'ro',
        isa      => Str,
        init_arg => undef,
        lazy     => 1,
        default  => sub { $formats{ $_[0]->date_style() }[1] },
    );

    class_has _DateFormats => (
        traits  => ['Hash'],
        is      => 'ro',
        isa     => HashRef [Str],
        lazy    => 1,
        default => sub {
            return {
                map { $_ => $formats{$_}[0] } keys %formats
            }
        },
        handles => { DateFormats => 'elements' },
    );
}

has date_format_for_jquery => (
    is       => 'ro',
    isa      => Str,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_date_format_for_jquery',
);

{
    my %formats = (
        12 => 'h:mm a',
        24 => 'HH:mm',
    );

    has time_format => (
        is       => 'ro',
        isa      => Str,
        init_arg => undef,
        lazy     => 1,
        default  => sub { $formats{ $_[0]->use_24_hour_time() ? 24 : 12 } },
    );

    class_has _TimeFormats => (
        traits  => ['Hash'],
        is      => 'ro',
        isa     => HashRef [Str],
        lazy    => 1,
        default => sub { \%formats },
        handles => { TimeFormats => 'elements' },
    );
}

has display_name => (
    is       => 'ro',
    isa      => Str,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_display_name',
);

class_has SystemUser => (
    is      => 'ro',
    isa     => __PACKAGE__,
    lazy    => 1,
    builder => '_FindOrCreateSystemUser',
);

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('User') );

    has_one account => (
        table => $schema->table('Account'),
    );

    has_one role => (
        table => $schema->table('Role'),
    );

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

around 'insert' => sub {
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    if ( $p{is_disabled} ) {
        $p{password} //= '*disabled*';
    }
    elsif ( !string_is_empty( $p{password} ) ) {
        $p{password} = $class->_password_as_rfc2307( $p{password} );
    }

    my %user_p = map { $_ => $p{$_} }
        grep { $class->Table()->column($_) } keys %p;

    my %person_p = map { $_ => $p{$_} }
        grep {
               R2::Schema::Person->Table()->column($_)
            || R2::Schema::Contact->Table()->column($_)
        } keys %p;

    my $sub = sub {
        my $person;
        if ( $p{account_id} ) {
            $person = R2::Schema::Person->insert(
                %person_p,
                user => $p{user},
            );

            if ( Email::Valid->address( $user_p{username} // q{} ) ) {
                R2::Schema::EmailAddress->insert(
                    email_address => $user_p{username},
                    contact_id    => $person->person_id(),
                    is_preferred  => 1,
                    user          => $p{user},
                );
            }

            $user_p{person_id} = $person->person_id();
        }

        my $user = $class->$orig(%user_p);

        $user->_set_person($person) if $person;

        return $user;
    };

    return R2::Schema->RunInTransaction($sub);
};

around update => sub {
    my $orig = shift;
    my $self = shift;
    my %p    = @_;

    unless ( string_is_empty( $p{password} ) ) {
        $p{password} = $self->_password_as_rfc2307( $p{password} );
    }

    $p{last_modified_datetime} = Fey::Literal::Function->new('NOW');

    my %user_p = map { $_ => $p{$_} }
        grep { $self->Table()->column($_) } keys %p;

    my %person_p = map { $_ => $p{$_} }
        grep {
               R2::Schema::Person->Table()->column($_)
            || R2::Schema::Contact->Table()->column($_)
        } keys %p;

    my $sub = sub {
        my $person = $self->person();

        if ($person) {
            $person->update(
                %person_p,
                user => $p{user},
            );
        }

        $self->$orig(%user_p);
    };

    R2::Schema->RunInTransaction($sub);

    return;
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
        cost        => 12,
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

sub EnsureRequiredUsersExist {
    my $class = shift;

    $class->_FindOrCreateSystemUser();
}

sub _FindOrCreateSystemUser {
    my $class = shift;

    my $user = $class->new( username => 'R2 System User' );
    return $user if $user;

    return $class->insert(
        user_id        => -1,
        username       => 'R2 System User',
        password       => '*unusable*',
        is_disabled    => 1,
        is_system_user => 1,
    );
}

sub _build_date_format_for_jquery {
    my $self = shift;

    my $format = $self->date_format();
    #<<<
    $format        =~ s/y{3,}/yy/
        or $format =~ s/yy/y/
        or $format =~ s/y/yy/
        or $format =~ s/u+/yy/;

    $format        =~ s/MMMMM/M/
        or $format =~ s/MMMM/MM/
        or $format =~ s/MMM/M/
        or $format =~ s/MM/mm/
        or $format =~ s/M/m/;

    $format        =~ s/LLLLL/M/
        or $format =~ s/LLLL/MM/
        or $format =~ s/LLL/M/
        or $format =~ s/L{1,2}/mm/;

    $format        =~ s/EEEEE/D/
        or $format =~ s/EEEE/DD/
        or $format =~ s/E{1,3}/D/;

    $format        =~ s/eeeee/D/
        or $format =~ s/eeee/DD/
        or $format =~ s/e{1,3}/D/;
    #>>>

    return $format;
}

sub format_date {
    my $self = shift;
    my $dt   = shift;

    return q{} unless $dt;

    my $format = $self->_date_format_for_dt($dt);

    return $dt->clone()->set_time_zone( $self->time_zone() )
        ->format_cldr($format);
}

sub format_date_with_year {
    my $self = shift;
    my $dt   = shift;

    return q{} unless $dt;

    return $dt->clone()->set_time_zone( $self->time_zone() )
        ->format_cldr( $self->date_format() );
}

sub _date_format_for_dt {
    my $self = shift;
    my $dt   = shift;

    my $today = DateTime->today( time_zone => $self->time_zone() );

    return $today->year() == $dt->year()
        ? $self->date_format_without_year()
        : $self->date_format();
}

sub format_time {
    my $self = shift;
    my $dt   = shift;

    return q{} unless $dt;

    return $dt->clone()->set_time_zone( $self->time_zone() )
        ->format_cldr( $self->time_format() );
}

sub format_datetime {
    my $self = shift;
    my $dt   = shift;

    return q{} unless $dt;

    my $format = $self->_date_format_for_dt($dt);
    $format .= q{ } . $self->time_format();

    return $dt->clone()->set_time_zone( $self->time_zone() )
        ->format_cldr($format);
}

sub _build_display_name {
    my $self = shift;

    return $self->person()
        ? $self->person()->display_name()
        : $self->username();
}

sub _base_uri_path {
    my $self = shift;

    return '/user/' . $self->user_id();
}

sub can_view_account {
    my $self = shift;
    my ($account) = validated_list(
        \@_,
        account => { isa => 'R2::Schema::Account' },
    );

    return $self->_require_at_least(
        $account->account_id(),
        'Member'
    );
}

sub can_edit_account {
    my $self = shift;
    my ($account) = validated_list(
        \@_,
        account => { isa => 'R2::Schema::Account' },
    );

    return $self->_require_at_least(
        $account->account_id(),
        'Admin'
    );
}

sub can_edit_user {
    my $self = shift;
    my ($user) = validated_list(
        \@_,
        user => { isa => 'R2::Schema::User' },
    );

    return 1 if $self->user_id() == $user->user_id();

    return $self->_require_at_least(
        $user->account_id(),
        'Admin'
    );
}

sub can_view_contact {
    my $self = shift;
    my ($contact) = validated_list(
        \@_,
        contact => { isa => ContactLike },
    );

    return $self->_require_at_least(
        $contact->account_id(),
        'Member'
    );
}

sub can_edit_contact {
    my $self = shift;
    my ($contact) = validated_list(
        \@_,
        contact => { isa => ContactLike },
    );

    return $self->_require_at_least(
        $contact->account_id(),
        'Editor'
    );
}

sub can_add_contact {
    my $self = shift;
    my ($account) = validated_list(
        \@_,
        account => { isa => 'R2::Schema::Account' },
    );

    return $self->_require_at_least(
        $account->account_id(),
        'Editor'
    );
}

{

    # This could go in the DBMS, but I'm uncomfortable with making
    # this a formal part of the data model. There could be additional
    # roles in the future that don't fit into this sort of scheme, so
    # keeping this ranking in code preserves the flexibility to
    # eliminate it entirely.
    my %RoleRank = (
        Member => 1,
        Editor => 2,
        Admin  => 3,
    );

    sub _require_at_least {
        my $self       = shift;
        my $account_id = shift;
        my $required   = shift;

        my $role = $self->role();

        return $RoleRank{ $role->name() } >= $RoleRank{$required} ? 1 : 0;
    }
}


__PACKAGE__->meta()->make_immutable();

1;

__END__
