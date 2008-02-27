package R2::Model::User;

use strict;
use warnings;

use Digest::SHA qw( sha512_base64 );
use List::Util qw( first );
use R2::Model::Party;
use R2::Model::Person;
use R2::Model::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    has_table( $schema->table('User') );

    has_one 'person' =>
        ( table   => $schema->table('Person'),
          handles => [ grep { ! __PACKAGE__->meta()->has_attribute($_) }
                       grep { $_ ne 'person' }
                       R2::Model::Person->meta()->get_attribute_list(),
                       R2::Model::Party->DelegatableMethods() ],
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

    my $sub = sub { my $person = R2::Model::Person->insert(%p);

                    my $user = $class->$orig( %user_p,
                                              password  => $password,
                                              person_id => $person->person_id(),
                                            );

                    $user->_set_person($person);

                    return $user;
                  };


    return R2::Model::Schema->RunInTransaction($sub);
};

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
