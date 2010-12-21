package R2::Role::Schema::CustomFieldValue;

use strict;
use warnings;
use namespace::autoclean;

use Fey::Placeholder;

use MooseX::Role::Parameterized;
use MooseX::Params::Validate qw( validated_list );

requires '_ValidateValue';

with 'R2::Role::Schema::DataValidator' => {
    validate_on_insert => 0,
    validate_on_update => 0,
    steps              => ['_ValidateValue'],
};

parameter 'value_column' => (
    isa     => 'Str',
    default => 'value',
);

role {
    my $p     = shift;
    my %extra = @_;

    my $table = $extra{consumer}->table();

    my $column = $table->column( $p->value_column() )
        or die 'No ' . $p->value_column() . ' column in ' . $table->name();

    my $delete = R2::Schema->SQLFactoryClass()->new_delete();

    #<<<
    $delete->from ($table)
           ->where( $table->column('custom_field_id'),
                    '=', Fey::Placeholder->new() )
           ->and  ( $table->column('contact_id'),
                    '=', Fey::Placeholder->new() );
    #>>>
    method 'replace_value_for_contact' => sub {
        my $class = shift;
        my ( $field, $contact, $value ) = validated_list(
            \@_,
            field   => { isa => 'R2::Schema::CustomField' },
            contact => { isa => 'R2::Schema::Contact' },
            value   => { isa => 'Defined' },
        );

        my %p = (
            value           => $value,
            contact_id      => $contact->contact_id(),
            custom_field_id => $field->custom_field_id()
        );

        $class->_clean_and_validate_data( \%p, 'is insert' );

        R2::Schema->RunInTransaction(
            sub {
                $class->_replace_value_for_contact(
                    $delete,
                    $field->custom_field_id(),
                    $contact->contact_id(),
                    $p{value},
                );
            }
        );
    };
};

sub _replace_value_for_contact {
    my $class           = shift;
    my $delete          = shift;
    my $custom_field_id = shift;
    my $contact_id      = shift;
    my $value           = shift;

    my $dbh = $class->_dbh($delete);

    $dbh->do(
        $delete->sql($dbh), {},
        $custom_field_id, $contact_id
    );

    $class->insert(
        custom_field_id => $custom_field_id,
        contact_id      => $contact_id,
        value           => $value,
    );
}

1;
