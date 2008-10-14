package R2::Schema::User;

use strict;
use warnings;

use Digest::SHA qw( sha512_base64 );
use Fey::ORM::Exceptions qw( no_such_row );
use List::Util qw( first );
use R2::Schema;
use R2::Schema::Contact;
use R2::Schema::EmailAddress;
use R2::Schema::Person;
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::DataValidator', 'R2::Role::URIMaker';


{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('User') );

    has_one 'person' =>
        ( table   => $schema->table('Person'),
          handles => [ grep { ! __PACKAGE__->meta()->has_attribute($_) }
                       grep { $_ ne 'person' }
                       R2::Schema::Person->meta()->get_attribute_list(),
                       R2::Schema::Contact->meta()->get_attribute_list(),
                       qw( display_name ),
                     ],
        );

    class_has '_ValidationSteps' =>
        ( is      => 'ro',
          isa     => 'ArrayRef[Str]',
          lazy    => 1,
          default => sub { [ qw( _validate_password _require_username_or_email ) ] },
        );
}


around 'insert' => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    my $password;

    if ( delete $p{disable_login} )
    {
        $password = '*disabled*';
    }
    elsif ( $p{password} )
    {
        # XXX - require a certain length or complexity? make it
        # configurable?
        $password = sha512_base64( delete $p{password} );
    }

    my %user_p =
        map { $_ => delete $p{$_} } grep { $class->Table()->column($_) } keys %p;

    $user_p{username} ||= $p{email_address};

    my $email_address = delete $p{email_address};

    my $sub = sub { my $person = R2::Schema::Person->insert(%p);

                    unless ( string_is_empty($email_address) )
                    {
                        R2::Schema::EmailAddress->insert
                            ( email_address => $email_address,
                              contact_id    => $person->person_id(),
                              is_preferred  => 1,
                            );
                    }

                    my $user = $class->$orig( %user_p,
                                              password => $password,
                                              user_id  => $person->person_id(),
                                            );

                    $user->_set_person($person);

                    return $user;
                  };

    return R2::Schema->RunInTransaction($sub);
};

# XXX - need an update wrapper for password hashing!

sub _validate_password
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return
        unless exists $p->{password} || $is_insert;

    return { message => 'A user requires a password.',
             field   => 'password',
           }
        if string_is_empty( $p->{password} ) && ! $p->{disable_login};

    return;
}

sub _require_username_or_email
{
    my $self = shift;
    my $p    = shift;
    my $is_insert = shift;

    return unless $is_insert;

    return { message => 'A user must have a username or email address.',
             field   => 'username',
           }
        if string_is_empty( $p->{username} ) && string_is_empty( $p->{email_address} );

    return;
}

sub _load_from_dbms
{
    my $self = shift;
    my $p    = shift;

    # This gets set to the unhashed value in the constructor
    $self->_clear_password();

    $self->SUPER::_load_from_dbms($p);

    return unless $p->{password};

    no_such_row 'Invalid password'
        unless $self->password() eq sha512_base64( $p->{password} );
}

sub format_date
{
    my $self = shift;
    my $dt   = shift;

    return $dt->format_cldr( $self->date_format() );
}

sub format_datetime
{
    my $self = shift;
    my $dt   = shift;

    return $dt->format_cldr( $self->date_format() . q{ } . $self->time_format() );
}

sub _base_uri_path
{
    my $self = shift;

    return '/user/' . $self->user_id();
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
