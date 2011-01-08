package R2::Schema::CustomFieldGroup;

use strict;
use warnings;
use namespace::autoclean;

use Lingua::EN::Inflect qw( PL_N );
use List::AllUtils qw( any );
use R2::CustomFieldType;
use R2::Schema;
use R2::Schema::HTMLWidget;
use R2::Schema::CustomField;
use R2::Types qw( ArrayRef Str PosOrZeroInt );
use R2::Util qw( string_is_empty );
use Sub::Name qw( subname );

use Fey::ORM::Table;

with 'R2::Role::Schema::DataValidator' => {
    steps => [
        qw(
            _display_order_is_unique
            _applies_to_something
            _cannot_unapply
            )
    ]
};

with 'R2::Role::Schema::AppliesToContactTypes';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('CustomFieldGroup') );

    has_one( $schema->table('Account') );

    has_many 'custom_fields' => (
        table => $schema->table('CustomField'),
        cache => 1,
        order_by =>
            [ $schema->table('CustomField')->column('display_order') ],
    );

    has 'custom_field_ids' => (
        is      => 'ro',
        isa     => ArrayRef,
        lazy    => 1,
        default => sub {
            [ map { $_->custom_field_id() } $_[0]->custom_fields()->all() ];
        },
        init_arg => undef,
    );

    has 'custom_field_count' => (
        is       => 'ro',
        isa      => PosOrZeroInt,
        lazy     => 1,
        default  => sub { scalar @{ $_[0]->custom_field_ids() } },
        init_arg => undef,
    );

    my @cf_types = R2::CustomFieldType->All();

    for my $contact_type (qw( Person Household Organization )) {
        my $contact_type_table = $schema->table($contact_type);

        my $get_count = sub {
            my $self = shift;

            return 0 unless @{ $self->custom_field_ids() };

            my $schema = R2::Schema->Schema();

            my $count = 0;
            for my $cf_type ( map { $_->type() }
                $self->custom_fields()->all() ) {
                my $cf_value_table = $cf_type->table();

                my $select = R2::Schema->SQLFactoryClass()->new_select();

                my $count = Fey::Literal::Function->new(
                    'COUNT',
                    $cf_value_table->column('contact_id')
                );

                #<<<
                $select
                    ->select($count)
                    ->from  ( $cf_value_table, $schema->table('Contact') )
                    ->where ( $cf_value_table->column('custom_field_id'), 'IN',
                              @{ $self->custom_field_ids() } )
                    ->and   ( $schema->table('Contact')->column('contact_type'),
                              '=', $contact_type );
                #>>>
                my $dbh = $self->_dbh($select);

                $count += $dbh->selectrow_arrayref(
                    $select->sql($dbh), {},
                    $select->bind_params()
                )->[0];
            }

            return $count;
        };

        has lc $contact_type
            . '_count' => (
            is       => 'ro',
            isa      => PosOrZeroInt,
            lazy     => 1,
            default  => $get_count,
            init_arg => undef,
            );
    }

    my $get_count = sub {
        my $self = shift;

        return 0 unless @{ $self->custom_field_ids() };

        my $schema = R2::Schema->Schema();

        my $count = 0;
        for my $cf_type (@cf_types) {
            my $cf_value_table = $cf_type->table();

            my $select = R2::Schema->SQLFactoryClass()->new_select();

            my $count = Fey::Literal::Function->new(
                'COUNT',
                $cf_value_table->column('contact_id')
            );

            #<<<
            $select
                ->select($count)
                ->from  ($cf_value_table)
                ->where( $cf_value_table->column('custom_field_id'), 'IN',
                         @{ $self->custom_field_ids() } );
            #>>>
            my $dbh = $self->_dbh($select);

            $count += $dbh->selectrow_arrayref(
                $select->sql($dbh), {},
                $select->bind_params()
            )->[0];
        }

        return $count;
    };

    has 'contact_count' => (
        is       => 'ro',
        isa      => PosOrZeroInt,
        lazy     => 1,
        default  => $get_count,
        init_arg => undef,
    );
}

with 'R2::Role::Schema::HasDisplayOrder' =>
    { related_column => __PACKAGE__->Table()->column('account_id') };

sub _display_order_is_unique {
    return;
}

sub update_or_add_custom_fields {
    my $self     = shift;
    my $existing = shift;
    my $new      = shift;

    my @fields = $self->custom_fields()->all();

    my $display_order = scalar @fields;

    my $sub = subname(
        'R2::Schema::_update_or_add_custom_fields' => sub {
            for my $field (@fields) {
                my $updated_field = $existing->{ $field->custom_field_id() };

                if ( string_is_empty( $updated_field->{label} ) ) {
                    next unless $field->is_deletable();

                    $field->delete();
                }
                else {
                    $field->update( %{$updated_field} );
                }
            }

            for my $new_field ( @{$new} ) {
                my $widget = R2::Schema::HTMLWidget->new(
                    name => $new_field->{type} );

                R2::Schema::CustomField->insert(
                    %{$new_field},
                    display_order         => ++$display_order,
                    html_widget_id        => $widget->html_widget_id(),
                    custom_field_group_id => $self->custom_field_group_id(),
                    account_id            => $self->account_id(),
                );
            }
        }
    );

    R2::Schema->RunInTransaction($sub);

}

__PACKAGE__->meta()->make_immutable();

1;

__END__
