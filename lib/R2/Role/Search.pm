package R2::Role::Search;

use Moose::Role;
use MooseX::ClassAttribute;

use namespace::autoclean;

use Class::Load qw( load_class );
use List::AllUtils qw( all );
use Module::Pluggable::Object;
use R2::Types qw(
    ArrayRef
    HashRef
    NonEmptyStr
    PosInt
    PosOrZeroInt
    SearchPlugin
);

requires qw(
    _BuildCountSelectBase
    _BuildObjectSelectBase
    _BuildSearchedClasses
    _iterator_class
    _classes_returned_by_iterator
    _bind_params
);

has order_by => (
    is        => 'ro',
    isa       => NonEmptyStr,
    predicate => '_has_order_by',
);

has limit => (
    is      => 'ro',
    isa     => PosOrZeroInt,
    default => 0,
);

has page => (
    is      => 'ro',
    isa     => PosInt,
    default => 1,
);

has _restrictions => (
    traits   => ['Array'],
    isa      => ArrayRef [SearchPlugin],
    init_arg => undef,
    lazy     => 1,
    default  => sub { [] },
    handles  => {
        _restrictions     => 'elements',
        _add_restrictions => 'push',
        _has_restrictions => 'count',
    },
);

class_has _CountSelectBase => (
    is       => 'ro',
    does     => 'Fey::Role::Selectable',
    init_arg => undef,
    lazy     => 1,
    builder  => '_BuildCountSelectBase',
);

class_has _ObjectSelectBase => (
    is       => 'ro',
    does     => 'Fey::Role::Selectable',
    init_arg => undef,
    lazy     => 1,
    builder  => '_BuildObjectSelectBase',
);

class_has _SearchedClasses => (
    traits   => ['Hash'],
    isa      => HashRef,
    init_arg => undef,
    lazy     => 1,
    builder  => '_BuildSearchedClasses',
    handles  => {
        _SearchIncludesClass => 'get',
    },
);

sub BUILD { }

after BUILD => sub {
    my $self = shift;
    my $p    = shift;

    die "Invalid order_by parameter: " . $self->order_by()
        if $self->_has_order_by()
            && !$self->can( '_order_by_' . $self->order_by() );

    $self->_load_and_set_restrictions( delete $p->{restrictions}, $p );
};

sub _load_and_set_restrictions {
    my $self         = shift;
    my $restrictions = shift;
    my $p            = shift;

    my @restrictions
        = $restrictions && ref $restrictions eq 'ARRAY' ? @{$restrictions}
        : defined $restrictions ? $restrictions
        :                         ();

    return unless @restrictions;

    local $p->{search} = $self;

    for my $class ( map { $self->_ResolvePlugin($_) } @restrictions ) {
        my $plugin = $class->new($p);
        $self->_add_restrictions($plugin);
    }
};

sub _object_iterator {
    my $self = shift;

    my $select = $self->_ObjectSelectBase->clone();

    $self->_apply_where_clauses($select);

    if ( $self->_has_order_by() ) {
        my $order_by_meth = '_order_by_' . $self->order_by();
        $self->$order_by_meth($select);
    }

    $self->_apply_limit($select);

    return $self->_iterator_class()->new(
        classes => $self->_classes_returned_by_iterator(),
        dbh =>
            R2::Schema->DBIManager()->source_for_sql($select)->dbh(),
        select      => $select,
        bind_params => [ $self->_bind_params($select) ],
    );
}

sub _count {
    my $self = shift;

    my $select = $self->_CountSelectBase()->clone();

    $self->_apply_where_clauses($select);

    my $dbh = R2::Schema->DBIManager()->source_for_sql($select)->dbh();

    my $row = $dbh->selectrow_arrayref(
        $select->sql($dbh),
        {},
        $self->_bind_params($select),
    );

    return $row ? $row->[0] : 0;
}

sub _apply_where_clauses {
    my $self = shift;
    my $select = shift;

    if ( $self->_has_restrictions() ) {
        $select->where( '(' );

        for my $plugin ( $self->_restrictions() ) {
            $plugin->apply_where_clauses($select);
        }

        $select->where( ')' );
    }
}

sub _apply_limit {
    my $self   = shift;
    my $select = shift;

    return unless $self->limit();

    my @limit = $self->limit();
    push @limit, ( $self->page() - 1 ) * $self->limit();

    $select->limit(@limit);
}

sub searches_class {
    my $self = shift;

    return all { $self->_SearchIncludesClass($_) }
        map { /^R2::Schema::/ ? $_ : 'R2::Schema::' . $_ } @_;
}

{
    my %Plugins;

    sub _LoadAllPlugins {
        my $class = shift;

        return if %Plugins;

        my $finder = Module::Pluggable::Object->new(
            search_path => ['R2::Search::Plugin'],
            instantiate => undef,
        );

        %Plugins = map { $_ => 1 } $finder->plugins();

        load_class($_) for keys %Plugins;

        return;
    }

    sub _ResolvePlugin {
        my $self = shift;
        my $orig_name = shift;

        my $name
            = $orig_name =~ /^R2::Search::Plugin::/
            ? $orig_name
            : 'R2::Search::Plugin::' . $orig_name;

        die "Invalid plugin name ($orig_name)"
            unless $Plugins{$name};

        return $name;
    }
}

1;
