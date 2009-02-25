package R2::Role::CustomFieldValue;

use strict;
use warnings;

use Fey::Placeholder;

use MooseX::Role::Parameterized;
use MooseX::Params::Validate qw( validated_list );

parameter 'value_column' =>
    ( isa     => 'Str',
      default => 'value',
    );


role
{
    my $p     = shift;
    my %extra = @_;

    my $table = $extra{consumer}->table();

    my $column = $table->column( $p->value_column() )
        or die 'No ' . $p->value_column() . ' column in ' . $table->name();

    my $delete = R2::Schema->SQLFactoryClass()->new_delete();

    $delete->from($table)
           ->where( $table->column('custom_field_id'), '=', Fey::Placeholder->new() )
           ->and  ( $table->column('contact_id'), '=', Fey::Placeholder->new() );

    method 'replace_value_for_contact' => sub
    {
        my $class = shift;
        my ( $field, $contact, $value ) =
            validated_list( \@_,
                            field   => { isa => 'R2::Schema::CustomField' },
                            contact => { isa => 'R2::Schema::Contact' },
                            value   => { isa => 'Defined' },
                          );

        R2::Schema->RunInTransaction
            ( sub
              {
                  $class->_replace_value_for_contact
                      ( $delete,
                        $field->custom_field_id(),
                        $contact->contact_id(),
                        $value,
                      );
              }
            );
    };
};

sub _replace_value_for_contact
{
    my $class           = shift;
    my $delete          = shift;
    my $custom_field_id = shift;
    my $contact_id      = shift;
    my $value           = shift;

    my $dbh = R2::Schema->DBIManager()->source_for_sql($delete)->dbh();

    $dbh->do( $delete->sql($dbh), {},
              $custom_field_id, $contact_id );

    $class->insert( custom_field_id => $custom_field_id,
                    contact_id      => $contact_id,
                    value           => $value,
                  );
}

no MooseX::Role::Parameterized;

1;
