package R2::Schema::RelationshipType;

use strict;
use warnings;
use namespace::autoclean;

use Lingua::EN::Inflect qw( PL_N );
use List::AllUtils qw( any );
use R2::Schema;
use R2::Types qw( PosOrZeroInt );

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('RelationshipType') );

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $schema->table('PersonRelationship')->column('person_id')
    );

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    #<<<
    $select
        ->select($count)
        ->from  ( $schema->tables('PersonRelationship') )
        ->where ( $schema->table('PersonRelationship')->column('relationship_type_id'),
                  '=', Fey::Placeholder->new() );
    #>>>
    query person_count => (
        select      => $select,
        bind_params => sub { $_[0]->relationship_type_id() },
    );
}

sub CreateDefaultsForAccount {
    my $class   = shift;
    my $account = shift;

    $class->insert(
        name         => 'sibling of',
        inverse_name => 'sibling of',
        account_id   => $account->account_id(),
    );

    $class->insert(
        name         => 'parent of',
        inverse_name => 'child of',
        account_id   => $account->account_id(),
    );

    $class->insert(
        name         => 'grandparent of',
        inverse_name => 'grandchild of',
        account_id   => $account->account_id(),
    );

    $class->insert(
        name         => 'friend of',
        inverse_name => 'friend of',
        account_id   => $account->account_id(),
    );

    $class->insert(
        name         => 'coworker of',
        inverse_name => 'coworker of',
        account_id   => $account->account_id(),
    );
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
