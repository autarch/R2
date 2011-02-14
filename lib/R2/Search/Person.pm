package R2::Search::Person;

use Moose;
# Cannot use StrictConstructor with plugins

use namespace::autoclean;

use Fey::Literal::Function;
use Fey::Object::Iterator::FromSelect;
use Fey::Placeholder;
use R2::Schema;
use R2::Types qw( ArrayRef );

has account => (
    is       => 'ro',
    isa      => 'R2::Schema::Account',
    required => 1,
);

with 'R2::Role::Search';

has '+order_by' => ( default => 'name' );

__PACKAGE__->_LoadAllPlugins();

{
    my $schema = R2::Schema->Schema();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $select_base = R2::Schema->SQLFactoryClass()->new_select();

    $select_base->from( $schema->table('Contact'), $schema->table('Person') );

    $select_base->where(
        $schema->table('Contact')->column('account_id'),
        '=', Fey::Placeholder->new()
    );

    my $object_select_base
        = $select_base->clone()->select( $schema->table('Person') );

    sub _BuildObjectSelectBase {$object_select_base}

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $schema->table('Person')->column('person_id')
    );

    my $count_select_base = $select_base->clone()->select($count);

    sub _BuildCountSelectBase {$count_select_base}
}

sub people {
    my $self = shift;

    return $self->_object_iterator();
}

sub _iterator_class {'Fey::Object::Iterator::FromSelect'}

sub _classes_returned_by_iterator {
    [ 'R2::Schema::Person' ]
}

sub _order_by_name {
    my $self   = shift;
    my $select = shift;

    my $schema = R2::Schema->Schema();

    $select->order_by(
        $schema->table('Person')->columns( 'last_name', 'first_name' ) );

    return;
}

sub person_count {
    my $self = shift;

    $self->_count();
}

sub _bind_params {
    my $self   = shift;
    my $select = shift;

    return $self->account()->account_id(), $select->bind_params();
}

sub _BuildSearchedClasses {
    return { 'R2::Schema::Person' => 1 };
}

sub _build_title {
    my $self = shift;

    return 'All People' unless $self->_has_restrictions();

    return 'X';
}

__PACKAGE__->meta()->make_immutable();

1;
