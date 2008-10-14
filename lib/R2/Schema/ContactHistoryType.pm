package R2::Schema::ContactHistoryType;

use strict;
use warnings;

use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;


{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('ContactHistoryType') );

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $count =
        Fey::Literal::Function->new
            ( 'COUNT', @{ $schema->table('ContactHistory')->primary_key() } );

    $select->select($count)
           ->from( $schema->tables( 'ContactHistory' ),  )
           ->where( $schema->table('ContactHistory')->column('contact_history_type_id'),
                    '=', Fey::Placeholder->new() );

    has 'history_count' =>
        ( metaclass   => 'FromSelect',
          is          => 'ro',
          isa         => 'R2::Type::PosOrZeroInt',
          lazy        => 1,
          select      => $select,
          bind_params => sub { $_[0]->contact_history_type_id() },
        );

    for my $type ( __PACKAGE__->_Types() )
    {
        my $name = $type->{system_name};

        class_has $name =>
            ( is      => 'ro',
              isa     => 'R2::Schema::ContactHistoryType',
              lazy    => 1,
              default => sub { __PACKAGE__->_CreateOrFindType($type) },
            );
    }
}

sub _CreateOrFindType
{
    my $class = shift;
    my $type  = shift;

    my $obj = $class->new( system_name => $type->{system_name} );

    $obj ||= $class->insert( %{ $type } );

    return $obj;
}

sub _Types
{
    return ( { system_name => 'Created',
               description => 'Contact was created',
               sort_order  => 1,
             },

             { system_name => 'Modified',
               description => 'Contact was modified',
               sort_order  => 2,
             },

             { system_name => 'AddEmailAddress',
               description => 'A new email address was added for the contact',
               sort_order  => 3,
             },

             { system_name => 'DeleteEmailAddress',
               description => 'An email address for the contact was deleted',
               sort_order  => 4,
             },

             { system_name => 'ModifyEmailAddress',
               description => 'An email address for the contact was modified',
               sort_order  => 5,
             },

             { system_name => 'AddWebsite',
               description => 'A new website was added for the contact',
               sort_order  => 6,
             },

             { system_name => 'DeleteWebsite',
               description => 'A website for the contact was deleted',
               sort_order  => 7,
             },

             { system_name => 'ModifyWebsite',
               description => 'A website for the contact was modified',
               sort_order  => 8,
             },

             { system_name => 'AddAddress',
               description => 'A new address was added for the contact',
               sort_order  => 9,
             },

             { system_name => 'DeleteAddress',
               description => 'An address for the contact was deleted',
               sort_order  => 10,
             },

             { system_name => 'ModifyAddress',
               description => 'An address for the contact was modified',
               sort_order  => 11,
             },

             { system_name => 'AddPhoneNumber',
               description => 'A new phone number was added for the contact',
               sort_order  => 12,
             },

             { system_name => 'DeletePhoneNumber',
               description => 'A phone number for the contact was deleted',
               sort_order  => 13,
             },

             { system_name => 'ModifyPhoneNumber',
               description => 'A phone number for the contact was modified',
               sort_order  => 14,
             },
           );
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
