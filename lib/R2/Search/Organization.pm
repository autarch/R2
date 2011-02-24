package R2::Search::Organization;

use Moose;
# Cannot use StrictConstructor with plugins

use namespace::autoclean;

use Fey::Literal::Function;
use Fey::Object::Iterator::FromSelect;
use R2::Schema;
use R2::Types qw( ArrayRef );

has account => (
    is       => 'ro',
    isa      => 'R2::Schema::Account',
    required => 1,
);

with 'R2::Role::Search::Contact';

has '+order_by' => ( default => 'name' );

__PACKAGE__->_LoadAllPlugins();

{
    my $schema = R2::Schema->Schema();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $select_base = R2::Schema->SQLFactoryClass()->new_select();

    $select_base->from( $schema->table('Contact'), $schema->table('Organization') );

    my $object_select_base
        = $select_base->clone()->select( $schema->table('Organization') );

    sub _BuildObjectSelectBase {$object_select_base}

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $schema->table('Organization')->column('organization_id')
    );

    my $count_select_base = $select_base->clone()->select($count);

    sub _BuildCountSelectBase {$count_select_base}
}

sub _iterator_class {'Fey::Object::Iterator::FromSelect'}

sub _classes_returned_by_iterator {
    [ 'R2::Schema::Organization' ]
}

sub _BuildOrderByNameClause {
    my $schema = R2::Schema->Schema();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    #<<<
    my $term =
        Fey::Literal::Term->new(
            $schema->table('Organization')->column('name')
                ->sql_or_alias($dbh)
        );
    #>>>

    $term->set_alias_name('_orderable_name');

    return $term;
}

__PACKAGE__->meta()->make_immutable();

1;
