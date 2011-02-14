package R2::Search::Contact;

use Moose;
# Cannot use StrictConstructor with plugins

use namespace::autoclean;

use Fey::Literal::Function;
use Fey::Literal::Term;
use Fey::Object::Iterator::FromSelect;
use Fey::Placeholder;
use List::AllUtils qw( any );
use R2::Schema;
use R2::Search::Iterator::RealContact;
use R2::Types qw( NonEmptyStr );

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

    my $object_select_base = $select_base->clone()
        ->select( $schema->tables( 'Person', 'Household', 'Organization' ) );

    sub _BuildObjectSelectBase {$object_select_base}

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $schema->table('Contact')->column('contact_id')
    );

    my $count_select_base = $select_base->clone()->select($count);

    sub _BuildCountSelectBase {$count_select_base}
}

sub contacts {
    my $self = shift;

    return $self->_object_iterator();
}

sub _iterator_class {'R2::Search::Iterator::RealContact'}

sub _classes_returned_by_iterator {
    [qw( R2::Schema::Person R2::Schema::Household R2::Schema::Organization )];
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

    sub _order_by_name {
        my $self   = shift;
        my $select = shift;

        $select->select($order_by_func);
        $select->order_by($order_by_func);

        return;
    }
}

sub contact_count {
    my $self = shift;

    $self->_count();
}

sub _bind_params {
    my $self   = shift;
    my $select = shift;

    return $self->account()->account_id(), $select->bind_params();
}

sub _BuildSearchedClasses {
    return { map { $_ => 1 }
            qw( R2::Schema::Person R2::Schema::Household R2::Schema::Organization )
    };
}

sub _build_title {
    my $self = shift;

    return 'All Contacts' unless $self->_has_restrictions();

    return 'X';
}

__PACKAGE__->meta()->make_immutable();

1;
