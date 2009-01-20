package R2::Schema::AddressType;

use strict;
use warnings;

use Lingua::EN::Inflect qw( PL_N );
use List::MoreUtils qw( any );
use R2::Schema;
use R2::Types;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::DataValidator', 'R2::Role::AppliesToContactTypes';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('AddressType') );

    for my $type ( qw( Person Household Organization ) )
    {
        my $foreign_table = $schema->table($type);

        my $select = R2::Schema->SQLFactoryClass()->new_select();

        my $count =
            Fey::Literal::Function->new
                ( 'COUNT', $schema->table('Contact')->column('contact_id') );

        $select->select($count)
               ->from( $schema->tables( 'Address', 'Contact' ) )
               ->where( $schema->table('Address')->column('address_type_id'),
                        '=', Fey::Placeholder->new() )
               ->and( $schema->table('Contact')->column('contact_type'), '=', Fey::Placeholder->new() );

        has lc $type . '_count' =>
            ( metaclass   => 'FromSelect',
              is          => 'ro',
              isa         => 'R2.Type.PosOrZeroInt',
              lazy        => 1,
              select      => $select,
              bind_params => sub { $_[0]->address_type_id(), $type },
            );
    }

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $count =
        Fey::Literal::Function->new
            ( 'COUNT', @{ $schema->table('Contact')->primary_key() } );

    $select->select($count)
           ->from( $schema->table('Address') )
           ->where( $schema->table('Address')->column('address_type_id'),
                    '=', Fey::Placeholder->new() );

    has 'contact_count' =>
        ( metaclass   => 'FromSelect',
          is          => 'ro',
          isa         => 'R2.Type.PosOrZeroInt',
          lazy        => 1,
          select      => $select,
          bind_params => sub { $_[0]->address_type_id() },
        );

    class_has '_ValidationSteps' =>
        ( is      => 'ro',
          isa     => 'ArrayRef[Str]',
          lazy    => 1,
          default => sub { [ qw( _applies_to_something _cannot_unapply ) ] },
        );
}


sub CreateDefaultsForAccount
{
    my $class   = shift;
    my $account = shift;

    $class->insert( name                    => 'Home',
                    applies_to_person       => 1,
                    applies_to_household    => 1,
                    applies_to_organization => 0,
                    account_id              => $account->account_id(),
                  );

    $class->insert( name                    => 'Work',
                    applies_to_person       => 1,
                    applies_to_household    => 0,
                    applies_to_organization => 0,
                    account_id              => $account->account_id(),
                  );

    $class->insert( name                    => 'Headquarters',
                    applies_to_person       => 0,
                    applies_to_household    => 0,
                    applies_to_organization => 1,
                    account_id              => $account->account_id(),
                  );

    $class->insert( name                    => 'Branch',
                    applies_to_person       => 0,
                    applies_to_household    => 0,
                    applies_to_organization => 1,
                    account_id              => $account->account_id(),
                  );
}

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
