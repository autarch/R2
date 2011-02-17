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
    # This is a complex SQL bit that sorts by the name of the person,
    # household, or organization for each row. People are sorted by last name
    # first. For households and organizations, we ignore a leading (the|a|an)
    # when sorting.
    my $order_by_func = do {
        my $schema = R2::Schema->Schema();

        my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

        my $sortable_name_sub = sub {
            my $col = shift;

            my $sql_regex = '(a|an|the)';

            #<<<
            my $replace
                = Fey::Literal::Term->new(
                    'REGEXP_REPLACE('
                    . $col->sql_or_alias($dbh)
                    . qq{, '$sql_regex'}
                    . q{, '' )} );
            #>>>

            #<<<
            return
                Fey::Literal::Term->new(
                  'CASE '
                  . ' WHEN '
                  . $col->sql_or_alias($dbh)
                  . ' ~* '
                  . qq{'$sql_regex .+'}
                  . ' THEN '
                  . $replace->sql_or_alias($dbh)
                  . ' ELSE '
                  . $col->sql_or_alias($dbh)
                  . ' END' )->sql_or_alias($dbh);
            #>>>
        };

        #<<<
        my $term
            = Fey::Literal::Term->new(
                'CASE '
                . $schema->table('Contact')->column('contact_type')
                      ->sql_or_alias($dbh)
                . q{ WHEN 'Person' THEN }
                . $schema->table('Person')->column('last_name')
                      ->sql_or_alias($dbh)
                . q{ || ' ' || }
                . $schema->table('Person')->column('first_name')
                      ->sql_or_alias($dbh)
                . q{ WHEN 'Household' THEN }
                . $sortable_name_sub->( $schema->table('Household')->column('name') )
                . q{ ELSE }
                . $sortable_name_sub->( $schema->table('Organization')->column('name') )
                . q{ END} );
        #>>>
        $term->set_alias_name('_orderable_name');

        $term;
    };

    sub _order_by_name {
        my $self   = shift;
        my $select = shift;

        $select->select($order_by_func);

        my $sort_order = $self->reverse_order() ? 'DESC' : 'ASC';

        $select->order_by( $order_by_func, $sort_order );

        return;
    }
}

{
    my $order_by_func = do {
        my $schema = R2::Schema->Schema();

        my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

        my $select = R2::Schema->SQLFactoryClass()->new_select();

        #<<<
        my $term
            = Fey::Literal::Term
                ->new( $schema->table('Address')->column('country')
                           ->sql_or_alias($dbh)
                       . q{ || '~~' || }
                       . $schema->table('Address')->column('postal_code')
                           ->sql_or_alias($dbh)
                       . q{ || '~~' || }
                       . $schema->table('Address')->column('region')
                           ->sql_or_alias($dbh)
                       . q{ || '~~' || }
                       . $schema->table('Address')->column('city')
                           ->sql_or_alias($dbh)
                       . q{ || '~~' || }
                       . $schema->table('Address')->column('street_1')
                           ->sql_or_alias($dbh)
                     );
        #>>>

        #<<
        $select
            ->select($term)
            ->from  ( $schema->table('Address') )
            ->where ( $schema->table('Address')->column('contact_id'),
                      '=', $schema->table('Contact')->column('contact_id') )
            ->and   ( $schema->table('Address')->column('is_preferred'),
                      '=', 1 )
            ->limit(1);
        #>>

        $select->set_alias_name('_orderable_location');

        $select;
    };

    sub _order_by_location {
        my $self   = shift;
        my $select = shift;

        $select->select($order_by_func);

        my $sort_order = $self->reverse_order() ? 'DESC' : 'ASC';

        $select->order_by(
            Fey::Literal::Term->new('_orderable_location'),
            $sort_order
        );

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

sub _base_uri_path {
    my $self = shift;

    return $self->account()->_base_uri_path() . '/contacts';
}

sub _build_title {
    my $self = shift;

    return 'All Contacts' unless $self->has_restrictions();

    return 'Contact Search';
}

__PACKAGE__->meta()->make_immutable();

1;
