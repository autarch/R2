package R2::Search::Person;

use strict;
use warnings;

use Fey::Literal::Function;
use Fey::Object::Iterator::FromSelect;
use Fey::Placeholder;
use R2::Schema;

use Moose;
use MooseX::ClassAttribute;

extends 'R2::Search';

{
    my $schema = R2::Schema->Schema();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $select_base = R2::Schema->SQLFactoryClass()->new_select();

    $select_base->from( $schema->table('Contact'), $schema->table('Person') );

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

sub people {
    my $self = shift;

    my $select = $self->_SelectBase->clone();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Person') );

    $select->order_by(
        $schema->table('Person')->columns( 'last_name', 'first_name' ) );

    $self->_apply_where_clauses($select);

    $self->_apply_limit($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes => 'R2::Schema::Person',
        dbh     => R2::Schema->DBIManager()->source_for_sql($select)->dbh(),
        select  => $select,
        bind_params => [ $self->account()->account_id() ],
    );
}

sub person_count {
    my $self = shift;

    my $schema = R2::Schema->Schema();

    my $count = Fey::Literal::Function->new( 'COUNT',
        $schema->table('Person')->column('contact_id') );

    my $select = $self->_SelectBase->clone();

    $select->select($count);

    $self->_apply_where_clauses($select);

    my $dbh = R2::Schema->DBIManager()->source_for_sql($select)->dbh();

    return $dbh->selectrow_arrayref( $select->sql($dbh), {},
        $self->account()->account_id() )->[0];
}

sub _apply_where_clauses { }

__PACKAGE__->meta()->make_immutable();

no Moose;
no MooseX::ClassAttribute;

1;
