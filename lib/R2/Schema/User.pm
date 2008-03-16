package R2::Schema::User;

use strict;
use warnings;

use Digest::SHA qw( sha512_base64 );
use Fey::ORM::Exceptions qw( no_such_row );
use List::Util qw( first );
use R2::Schema::Contact;
use R2::Schema::Person;
use R2::Schema;
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('User') );

    has_one 'person' =>
        ( table   => $schema->table('Person'),
          handles => [ grep { ! __PACKAGE__->meta()->has_attribute($_) }
                       grep { $_ ne 'person' }
                       R2::Schema::Person->meta()->get_attribute_list(),
                       R2::Schema::Contact->meta()->get_attribute_list() ],
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
        die 'A new user requires a password'
            unless $p{password};

        # XXX - require a certain length or complexity? make it
        # configurable?
        $password = sha512_base64( $p{password} );
    }

    delete $p{password};

    die 'A new user requires an email address'
        unless $p{email_address};

    my %user_p =
        map { $_ => delete $p{$_} } grep { $class->Table()->column($_) } keys %p;

    my $sub = sub { my $person = R2::Schema::Person->insert(%p);

                    my $user = $class->$orig( %user_p,
                                              password => $password,
                                              user_id  => $person->person_id(),
                                            );

                    $user->_set_person($person);

                    return $user;
                  };


    return R2::Schema->RunInTransaction($sub);
};

sub _load_from_dbms
{
    my $self = shift;
    my $p    = shift;

    return $self->SUPER::_load_from_dbms($p)
        if string_is_empty( $p->{email_address} )
        || string_is_empty( $p->{password} );

    my $email = delete $p->{email_address};

    # This gets set in the constructor to the unhashed value
    $self->_clear_password();

    my $contact = R2::Schema::Contact->new( email_address => $email )
        or no_such_row "No contact with the email_address = $email";

    my $person = $contact->person()
        or no_such_row 'Contact is not a person';

    unless ( $self->_load_from_key( [ $self->Table()->primary_key() ],
                                    [ $person->person_id() ],
                                  ) )
    {
        no_such_row 'Person is not a user';
    }

    # Without this, everything gets very confused, because the object
    # has no PK
    $self->_set_user_id( $person->person_id() );

    no_such_row 'Invalid password'
        unless $self->password() eq sha512_base64( $p->{password} );
}

make_immutable;

no Fey::ORM::Table;
no Moose;

1;

__END__
