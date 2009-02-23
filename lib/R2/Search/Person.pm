package R2::Search::Person;

use strict;
use warnings;

use Fey::Literal::Function;
use Fey::Object::Iterator::FromSelect;
use R2::Schema;

use Moose;

extends 'R2::Search::Contact';


my $Schema = R2::Schema->Schema();

sub people
{
    my $self = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $dbh = R2::Schema->DBIManager()->source_for_sql($select)->dbh();

    $select->select( $Schema->table('Person') );

    $self->_join($select);
    $self->_where_clauses($select);

    $select->order_by( $Schema->table('Person')->columns( 'last_name', 'first_name') );

    $self->_limit($select);

    return
        Fey::Object::Iterator::FromSelect->new
            ( classes     => 'R2::Schema::Person',
              dbh         => $dbh,
              select      => $select,
              bind_params => [ $select->bind_params() ],
            );
}

sub person_count
{
    my $self = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $dbh = R2::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $count =
        Fey::Literal::Function->new
            ( 'COUNT', $Schema->table('Person')->column('contact_id') );

    $select->select($count);

    $self->_join($select);
    $self->_where_clauses($select);

    return $dbh->selectrow_arrayref( $select->sql($dbh), {}, $select->bind_params() )->[0];
}

sub _join
{
    my $self   = shift;
    my $select = shift;

    $select->from( $Schema->table('Contact'), $Schema->table('Person') );
}

__PACKAGE__->meta()->make_immutable();

no Moose;

1;
