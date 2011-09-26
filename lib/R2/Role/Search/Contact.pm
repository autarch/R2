package R2::Role::Search::Contact;

use Moose::Role;
use MooseX::ClassAttribute;

use namespace::autoclean;

use R2::Types qw( Bool );

requires '_BuildOrderByNameClause';

with 'R2::Role::Search';

has includes_multiple_contact_types => (
    is      => 'ro',
    isa     => Bool,
    lazy    => 1,
    builder => '_build_includes_multiple_contact_types',
);

class_has _OrderByNameClause => (
    is      => 'ro',
    does    => 'Fey::Role::Selectable',
    lazy    => 1,
    builder => '_BuildOrderByNameClause',
);

after _apply_where_clauses => sub {
    my $self   = shift;
    my $select = shift;

    my $schema = R2::Schema->Schema();

    $select->where(
        $schema->table('Contact')->column('account_id'),
        '=', $self->account()->account_id(),
    );
};

sub contacts {
    my $self = shift;

    return $self->_object_iterator();
}

sub _order_by_name {
    my $self   = shift;
    my $select = shift;

    my $order_by = $self->_OrderByNameClause();

    $select->select($order_by);

    my $sort_order = $self->reverse_order() ? 'DESC' : 'ASC';

    $select->order_by( $order_by, $sort_order );

    return;
}

{
    my $order_by = do {
        my $schema = R2::Schema->Schema();

        my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

        my $select = R2::Schema->SQLFactoryClass()->new_select();

        #<<<
        $select
            ->select( $schema->table('EmailAddress')->column('email_address') )
            ->from  ( $schema->table('EmailAddress') )
            ->where ( $schema->table('EmailAddress')->column('contact_id'),
                      '=', $schema->table('Contact')->column('contact_id') )
            ->and   ( $schema->table('EmailAddress')->column('is_preferred'),
                      '=', 1 )
            ->limit(1);
        #>>>
        $select->set_alias_name('_orderable_email_address');

        $select;
    };

    sub _order_by_email_address {
        my $self   = shift;
        my $select = shift;

        $select->select($order_by);

        my $sort_order = $self->reverse_order() ? 'DESC' : 'ASC';

        $select->order_by(
            Fey::Literal::Term->new( $order_by->alias_name() ),
            $sort_order
        );

        return;
    }
}

{
    my $order_by = do {
        my $schema = R2::Schema->Schema();

        my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

        my $select = R2::Schema->SQLFactoryClass()->new_select();

        #<<<
        $select
            ->select( $schema->table('ContactHistory')->column('history_datetime') )
            ->from  ( $schema->table('ContactHistory') )
            ->where ( $schema->table('ContactHistory')->column('contact_id'),
                      '=', $schema->table('Contact')->column('contact_id') )
            ->order_by( $schema->table('ContactHistory')->column('history_datetime'), 'DESC' )
            ->limit(1);
        #>>>
        $select->set_alias_name('_orderable_modified');

        $select;
    };

    sub _order_by_modified {
        my $self   = shift;
        my $select = shift;

        my $name_clause = $self->_OrderByNameClause();

        $select->select( $order_by, $name_clause );

        my $sort_order = $self->reverse_order() ? 'ASC' : 'DESC';

        $select->order_by(
            Fey::Literal::Term->new( $order_by->alias_name() ),
            $sort_order,
            $name_clause,
            'ASC'
        );

        return;
    }
}

sub _order_by_created {
    my $self   = shift;
    my $select = shift;

    my $name_clause = $self->_OrderByNameClause();

    $select->select($name_clause);

    my $sort_order = $self->reverse_order() ? 'ASC' : 'DESC';

    my $schema = R2::Schema->Schema();

    $select->order_by(
        $schema->table('Contact')->column('creation_datetime'),
        $sort_order,
        $name_clause,
        'ASC',
    );

    return;
}

sub _build_includes_multiple_contact_types {
    my $self = shift;

    return $self->_SearchedClassCount() > 1;
}

sub _build_result_type_string {
    my $self = shift;

    return 'contact' if $self->includes_multiple_contact_types();

    for my $type (qw( person household organization )) {
        my $class = 'R2::Schema::' . ucfirst $type;

        return $type if $self->_SearchIncludesClass($class);
    }

    die 'wtf';
}

1;
