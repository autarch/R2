package R2::Search::Contact;

use strict;
use warnings;

use Fey::Literal::Function;
use Fey::Literal::Term;
use Fey::Object::Iterator::FromSelect;
use R2::Schema;
use R2::Types;

use Moose;

has 'account' =>
    ( is       => 'ro',
      isa      => 'R2::Schema::Account',
      required => 1,
    );

has 'limit' =>
    ( is      => 'ro',
      isa     => 'R2.Type.PosOrZeroInt',
      default => 0,
    );

has 'page' =>
    ( is      => 'ro',
      isa     => 'R2.Type.PosInt',
      default => 1,
    );


my $Schema = R2::Schema->Schema();

{
    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $order_by_func =
        Fey::Literal::Term->new
            ( 'CASE '
              . $Schema->table('Contact')->column('contact_type')->sql_or_alias($dbh)
              . q{ WHEN 'Person' THEN }
              . $Schema->table('Person')->column('last_name')->sql_or_alias($dbh)
              . q{ || ' ' || }
              . $Schema->table('Person')->column('first_name')->sql_or_alias($dbh)
              . q{ WHEN 'Household' THEN }
              . $Schema->table('Household')->column('name')->sql_or_alias($dbh)
              . q{ ELSE }
              . $Schema->table('Organization')->column('name')->sql_or_alias($dbh)
              . q{ END}
            );

    $order_by_func->set_alias_name('_orderable_name');

    sub contacts
    {
        my $self = shift;

        my $select = R2::Schema->SQLFactoryClass()->new_select();

        my $dbh = R2::Schema->DBIManager()->source_for_sql($select)->dbh();

        $select->select( $Schema->table('Contact'), $order_by_func );

        $self->_contact_join($select);
        $self->_where_clauses($select);

        $select->order_by($order_by_func);

        if ( $self->limit() )
        {
            my @limit = $self->limit();
            push @limit, ( $self->page() - 1 ) * $self->limit();

            $select->limit(@limit);
        }

        return
            Fey::Object::Iterator::FromSelect->new
                ( classes     => 'R2::Schema::Contact',
                  dbh         => $dbh,
                  select      => $select,
                  bind_params => [ $select->bind_params() ],
                );
    }
}

sub contact_count
{
    my $self = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $dbh = R2::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $count =
        Fey::Literal::Function->new
            ( 'COUNT', $Schema->table('Contact')->column('contact_id') );

    $select->select($count);

    $self->_contact_join($select);
    $self->_where_clauses($select);

    return $dbh->selectrow_arrayref( $select->sql($dbh), {}, $select->bind_params() )->[0];
}

sub _contact_join
{
    my $self   = shift;
    my $select = shift;

    $select->from( $Schema->table('Contact'), 'left', $Schema->table('Person') )
           ->from( $Schema->table('Contact'), 'left', $Schema->table('Household') )
           ->from( $Schema->table('Contact'), 'left', $Schema->table('Organization') );
}

sub _where_clauses
{
    my $self   = shift;
    my $select = shift;

    $select->where( $Schema->table('Contact')->column('account_id'),
                    '=', $self->account()->account_id() );
}

sub _limit
{
    my $self   = shift;
    my $select = shift;

    return unless $self->limit();

    my @limit = $self->limit();
    push @limit, ( $self->page() - 1 ) * $self->limit();

    $select->limit(@limit);
}

__PACKAGE__->meta()->make_immutable();

no Moose;

1;
