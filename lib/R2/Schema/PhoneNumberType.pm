package R2::Schema::PhoneNumberType;

use strict;
use warnings;

use Lingua::EN::Inflect qw( PL_N );
use List::MoreUtils qw( any );
use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

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
                ( 'COUNT', @{ $foreign_table->primary_key() } );

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
              isa         => 'R2.Type.PosOrZeroInt',
              lazy        => 1,
              select      => __PACKAGE__->$build_count_meth(),
              bind_params => sub { $_[0]->phone_number_type_id() },
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

    class_has '_ValidationSteps' =>
        ( is      => 'ro',
          isa     => 'ArrayRef[Str]',
          lazy    => 1,
          default => sub { [ qw( _cannot_unapply _applies_to_something ) ] },
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

sub _cannot_unapply
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    return if $is_insert;

    for my $contact_type ( qw( person household organization ) )
    {
        my $key = 'applies_to_' . $contact_type;

        if ( exists $p->{$key} && ! $p->{$key} )
        {
            my $meth = 'can_unapply_from_' . $contact_type;

            delete $p->{$key}
                unless $self->$meth();
        }
    }

    return;
}

sub _applies_to_something
{
    my $self      = shift;
    my $p         = shift;
    my $is_insert = shift;

    my @keys = map { 'applies_to_' . $_ } qw( person household organization );

    if ($is_insert)
    {
        return if
            any { exists $p->{$_} && $p->{$_} } @keys;
    }
    else
    {
        for my $key (@keys)
        {
            if ( exists $p->{$key} )
            {
                return if $p->{$key};
            }
            else
            {
                return if $self->$key();
            }
        }
    }

    return { message =>
             'A phone number type must apply to a person, household, or organization.' };
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
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
