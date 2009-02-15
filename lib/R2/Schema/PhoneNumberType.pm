package R2::Schema::PhoneNumberType;

use strict;
use warnings;

use Lingua::EN::Inflect qw( PL_N );
use List::MoreUtils qw( any );
use R2::Schema;
use R2::Types;

use Fey::ORM::Table;

with 'R2::Role::DataValidator' =>
         { steps => [ qw( _cannot_unapply _applies_to_something ) ] };
with 'R2::Role::AppliesToContactTypes';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('PhoneNumberType') );

    for my $type ( qw( Person Household Organization ) )
    {
        my $select = R2::Schema->SQLFactoryClass()->new_select();

        my $count =
            Fey::Literal::Function->new
                ( 'COUNT', $schema->table('Contact')->column('contact_id') );

        $select->select($count)
               ->from( $schema->tables( 'PhoneNumber', 'Contact' ) )
               ->where( $schema->table('PhoneNumber')->column('phone_number_type_id'),
                        '=', Fey::Placeholder->new() )
               ->and( $schema->table('Contact')->column('contact_type'), '=', Fey::Placeholder->new() );

        has lc $type . '_count' =>
            ( metaclass   => 'FromSelect',
              is          => 'ro',
              isa         => 'R2.Type.PosOrZeroInt',
              lazy        => 1,
              select      => $select,
              bind_params => sub { $_[0]->phone_number_type_id(), $type },
            );
    }

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $count =
        Fey::Literal::Function->new
            ( 'COUNT', @{ $schema->table('Contact')->primary_key() } );

    $select->select($count)
           ->from( $schema->tables( 'PhoneNumber', 'Contact' ),  )
           ->where( $schema->table('PhoneNumber')->column('phone_number_type_id'),
                    '=', Fey::Placeholder->new() );

    has 'contact_count' =>
        ( metaclass   => 'FromSelect',
          is          => 'ro',
          isa         => 'R2.Type.PosOrZeroInt',
          lazy        => 1,
          select      => $select,
          bind_params => sub { $_[0]->phone_number_type_id() },
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

    $class->insert( name                    => 'Office',
                    applies_to_person       => 1,
                    applies_to_household    => 0,
                    applies_to_organization => 1,
                    account_id              => $account->account_id(),
                  );

    $class->insert( name                    => 'Cell',
                    applies_to_person       => 1,
                    applies_to_household    => 0,
                    applies_to_organization => 0,
                    account_id              => $account->account_id(),
                  );
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
