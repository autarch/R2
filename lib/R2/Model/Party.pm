package R2::Model::Party;

use strict;
use warnings;

#use R2::Model::Account;
use R2::Model::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    has_table( $schema->table('Party') );

    has_one( $schema->table('Account') );

    has_one 'person' =>
        ( table => $schema->table('Person'),
          undef => 1,
        );

    has_one 'organization' =>
        ( table    => $schema->table('Organization'),
          undef => 1,
        );

    has_one 'household' =>
        ( table => $schema->table('Household'),
          undef => 1,
        );
}

before 'update' => sub
{
    my $self = shift;
    my %p    = @_;

    my $person = $self->person()
        or return;

    die 'Cannot remove an email address for a user'
        if    exists $p{email_address}
           && ! defined $p{email_address}
           && $person->user();
};

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
