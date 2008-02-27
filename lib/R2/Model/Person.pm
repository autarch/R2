package R2::Model::Person;

use strict;
use warnings;

use R2::Model::Party;
use R2::Model::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    my $user_t = $schema->table('Person');

    has_table $user_t;

    has_one 'party' =>
        ( table   => $schema->table('Party'),
          handles => [ grep { ! __PACKAGE__->meta()->has_attribute($_) }
                       R2::Model::Party->DelegatableMethods(),
                     ],
        );

    has_one 'user' =>
        ( table => $schema->table('User'),
          undef => 1,
        );
}


around 'insert' => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    my %person_p =
        map { $_ => delete $p{$_} } grep { $class->Table()->column($_) } keys %p;

    my $sub = sub { my $party = R2::Model::Party->insert( %p, party_type => 'Person' );

                    my $person =
                        $class->$orig( %person_p,
                                       person_id => $party->party_id(),
                                     );

                    $person->_set_party($party);

                    return $person;
                  };

    return R2::Model::Schema->RunInTransaction($sub);
};

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
