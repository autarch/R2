package R2::Schema::PhoneNumberType;

use strict;
use warnings;

use Lingua::EN::Inflect qw( PL_N );
use List::MoreUtils qw( any );
use R2::Schema;

use MooseX::ClassAttribute;
use Fey::ORM::Table;

with 'R2::Role::DataValidator';

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('PhoneNumberType') );

    for my $type ( qw( Person Household Organization ) )
    {
        my $pl_type = PL_N($type);

        my $class = 'R2::Schema::' . $type;

        my $foreign_table = $schema->table($type);

        my $select = R2::Schema->SQLFactoryClass()->new_select();

        my $count =
            Fey::Literal::Function->new
                ( 'COUNT', $foreign_table->primary_key() );

        $select->select($count)
               ->from( $schema->tables( 'PhoneNumber', 'Contact' ),  )
               ->from( $schema->table('Contact'), $foreign_table )
               ->where( $schema->table('PhoneNumber')->column('phone_number_type_id'),
                        '=', Fey::Placeholder->new() );

        my $build_count_meth = '_Build' . $type . 'CountSelect';
        __PACKAGE__->meta()->add_method
            ( $build_count_meth => sub { $select } );

        has lc $type . '_count' =>
            ( metaclass   => 'FromSelect',
              is          => 'ro',
              isa         => 'Int',
              select      => __PACKAGE__->$build_count_meth(),
              bind_params => sub { $_[0]->phone_number_type_id() },
            );
    }

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $count =
        Fey::Literal::Function->new
            ( 'COUNT', $schema->table('Contact')->primary_key() );

    $select->select($count)
           ->from( $schema->tables( 'PhoneNumber', 'Contact' ),  )
           ->where( $schema->table('PhoneNumber')->column('phone_number_type_id'),
                    '=', Fey::Placeholder->new() );

    has 'contact_count' =>
        ( metaclass   => 'FromSelect',
          is          => 'ro',
          isa         => 'Int',
          select      => $select,
          bind_params => sub { $_[0]->phone_number_type_id() },
        );

    class_has '_ValidationSteps' =>
        ( is      => 'ro',
          isa     => 'ArrayRef[Str]',
          lazy    => 1,
          default => sub { [ qw( _applies_to_something ) ] },
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

sub _applies_to_something
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    unless ( any { $_}
	     @{ $p }{ map { 'applies_to_' . $_ } qw( person household organization ) } )
    {
	return { message =>
		 'A phone number type must apply to a person, household, or organization.' };
    }

    return;
}

sub can_unapply_from_person
{
    my $self = shift;

    return ! $self->person_count();
}

sub can_unapply_from_household
{
    my $self = shift;

    return ! $self->household_count();
}

sub can_unapply_from_organization
{
    my $self = shift;

    return ! $self->organization_count();
}

sub is_deleteable
{
    my $self = shift;

    return ! $self->contact_count();
}

no Fey::ORM::Table;
no Moose;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
