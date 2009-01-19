package R2::Schema::CustomFieldGroup;

use strict;
use warnings;

use Lingua::EN::Inflect qw( PL_N );
use List::MoreUtils qw( any );
use R2::Schema;
use R2::Schema::CustomField;
use R2::Types;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with qw( R2::Role::DataValidator );


{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomFieldGroup') );

    has_one( $schema->table('Account') );

    has_many 'custom_fields' =>
        ( table    => $schema->table('CustomField'),
          cache    => 1,
          order_by => [ $schema->table('CustomField')->column('display_order') ],
        );

    has 'custom_field_ids' =>
        ( is       => 'ro',
          isa      => 'ArrayRef',
          lazy     => 1,
          default  => sub { [ map { $_->custom_field_id() } $_[0]->custom_fields()->all() ] },
          init_arg => undef,
        );

    has 'custom_field_count' =>
        ( is       => 'ro',
          isa      => 'R2.Type.PosOrZeroInt',
          lazy     => 1,
          default  => sub { scalar @{ $_[0]->custom_field_ids() } },
          init_arg => undef,
        );

    my $cf_types = R2::Schema::CustomField->Types();

    for my $contact_type ( qw( Person Household Organization ) )
    {
        my $contact_type_table = $schema->table($contact_type);

        my $get_count = sub
        {
            my $self = shift;

            return 0 unless @{ $self->custom_field_ids() };

            my $schema = R2::Schema->Schema();

            my $count = 0;
            for my $cf_type ( @{ $cf_types } )
            {
                my $cf_value_table = $schema->table( 'CustomField' . $cf_type . 'Value' );

                my $select = R2::Schema->SQLFactoryClass()->new_select();

                my $count =
                    Fey::Literal::Function->new
                        ( 'COUNT', $cf_value_table->column('contact_id') );

                $select->select($count)
                       ->from( $cf_value_table, $schema->table('Contact') )
                       ->where( $cf_value_table->column('custom_field_id'), 'IN',
                                @{ $self->custom_field_ids() } )
                       ->and( $schema->table('Contact')->column('contact_type'), '=', $contact_type );

                my $dbh = R2::Schema->DBIManager()->source_for_sql($select);

                $count += $dbh->selectrow_arrayref( $select->sql($dbh), {}, $select->bind_params() )->[0];
            }

            return $count;
        };

        has lc $contact_type . '_count' =>
            ( is       => 'ro',
              isa      => 'R2.Type.PosOrZeroInt',
              lazy     => 1,
              default  => $get_count,
              init_arg => undef,
            );
    }

    my $get_count = sub
    {
        my $self = shift;

        return 0 unless @{ $self->custom_field_ids() };

        my $schema = R2::Schema->Schema();

        my $count = 0;
        for my $cf_type ( @{ $cf_types } )
        {
            my $cf_value_table = $schema->table( 'CustomField' . $cf_type . 'Value' );

            my $select = R2::Schema->SQLFactoryClass()->new_select();

            my $count =
                Fey::Literal::Function->new
                    ( 'COUNT', $cf_value_table->column('contact_id') );

            $select->select($count)
                   ->from( $cf_value_table )
                   ->where( $cf_value_table->column('custom_field_id'), 'IN',
                            @{ $self->custom_field_ids() } );

            my $dbh = R2::Schema->DBIManager()->source_for_sql($select);

            $count += $dbh->selectrow_arrayref( $select->sql($dbh), {}, $select->bind_params() )->[0];
        }

        return $count;
    };

    has 'contact_count' =>
        ( is       => 'ro',
          isa      => 'R2.Type.PosOrZeroInt',
          lazy     => 1,
          default  => $get_count,
          init_arg => undef,
        );

    class_has '_ValidationSteps' =>
        ( is      => 'ro',
          isa     => 'ArrayRef[Str]',
          lazy    => 1,
          default => sub { [ qw( _display_order_is_unique _applies_to_something ) ] },
        );
}


sub _display_order_is_unique
{
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
             'A custom field group must apply to a person, household, or organization.' };
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
