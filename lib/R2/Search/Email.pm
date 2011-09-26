package R2::Search::Email;

use Moose;
# Cannot use StrictConstructor with plugins

use namespace::autoclean;

with 'R2::Role::Search';

has '+order_by' => (
    default => 'date',
);

{
    my $schema = R2::Schema->Schema();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $select_base = R2::Schema->SQLFactoryClass()->new_select();

    $select_base->from( $schema->table('Email') );

    my $object_select_base
        = $select_base->clone()->select( $schema->tables('Email') );

    sub _BuildObjectSelectBase {$object_select_base}

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $schema->table('Email')->column('email_id')
    );

    my $count_select_base = $select_base->clone()->select($count);

    sub _BuildCountSelectBase {$count_select_base}
}

sub emails {
    my $self = shift;

    return $self->_object_iterator();
}

sub _order_by_date {
    my $self   = shift;
    my $select = shift;

    my $schema = R2::Schema->Schema();

    my $sort_order = $self->reverse_order() ? 'ASC' : 'DESC';

    $select->order_by(
        $schema->table('Email')->column('email_datetime'),
        $sort_order
    );

    return;
}

sub _iterator_class {'Fey::Object::Iterator::FromSelect'}

sub _classes_returned_by_iterator {
    ['R2::Schema::Email'];
}

sub _build_result_type_string {
    return 'email';
}

__PACKAGE__->meta()->make_immutable();

1;
