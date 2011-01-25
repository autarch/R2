package R2::Search::Contact;

use strict;
use warnings;
use namespace::autoclean;

use Fey::Literal::Function;
use Fey::Literal::Term;
use Fey::Object::Iterator::FromSelect;
use Fey::Placeholder;
use R2::Schema;
use R2::Types;

use Moose;
use MooseX::ClassAttribute;

extends 'R2::Search';

has 'account' => (
    is       => 'ro',
    isa      => 'R2::Schema::Account',
    required => 1,
);

{
    my $schema = R2::Schema->Schema();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $select_base = R2::Schema->SQLFactoryClass()->new_select();

    #<<<
    $select_base
        ->from( $schema->table('Contact'), 'left',
                $schema->table('Person') )
        ->from( $schema->table('Contact'), 'left',
                $schema->table('Household') )
        ->from( $schema->table('Contact'), 'left',
                $schema->table('Organization') );
    #>>>

    $select_base->where(
        $schema->table('Contact')->column('account_id'),
        '=', Fey::Placeholder->new()
    );

    class_has '_SelectBase' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        default => sub {$select_base},
    );
}

{
    my $order_by_func = do {
        my $schema = R2::Schema->Schema();

        my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

        #<<<
        my $term
            = Fey::Literal::Term
                ->new( 'CASE '
                       . $schema->table('Contact')->column('contact_type')
                       ->sql_or_alias($dbh)
                       . q{ WHEN 'Person' THEN }
                       . $schema->table('Person')->column('last_name')
                       ->sql_or_alias($dbh)
                       . q{ || ' ' || }
                       . $schema->table('Person')->column('first_name')
                       ->sql_or_alias($dbh)
                       . q{ WHEN 'Household' THEN }
                       . $schema->table('Household')->column('name')
                       ->sql_or_alias($dbh)
                       . q{ ELSE }
                       . $schema->table('Organization')->column('name')
                       ->sql_or_alias($dbh)
                       . q{ END} );
        #>>>

        $term->set_alias_name('_orderable_name');

        $term;
    };

    sub contacts {
        my $self = shift;

        my $schema = R2::Schema->Schema();

        my $select = $self->_SelectBase->clone();

        $select->select( $schema->table('Contact'), $order_by_func );

        $self->_apply_where_clauses($select);

        $select->order_by($order_by_func);

        $self->_apply_limit($select);

        return Fey::Object::Iterator::FromSelect->new(
            classes => 'R2::Schema::Contact',
            dbh => R2::Schema->DBIManager()->source_for_sql($select)->dbh(),
            select      => $select,
            bind_params => [ $self->account()->account_id(), $select->bind_params() ],
        );
    }
}

sub _apply_where_clauses { }

sub contact_count {
    my $self = shift;

    my $schema = R2::Schema->Schema();

    my $count = Fey::Literal::Function->new( 'COUNT',
        $schema->table('Contact')->column('contact_id') );

    my $select = $self->_SelectBase->clone();

    $select->select($count);

    my $dbh = R2::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $row = $dbh->selectrow_arrayref(
        $select->sql($dbh), {},
        $self->account()->account_id(), $select->bind_params(),
    );

    return $row ? $row->[0] : 0;
}

__PACKAGE__->meta()->make_immutable();

1;
