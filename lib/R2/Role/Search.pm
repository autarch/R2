package R2::Role::Search;

use Moose::Role;
use MooseX::ClassAttribute;

use namespace::autoclean;

use Class::Load qw( load_class );
use Data::Pageset;
use List::AllUtils qw( all );
use Module::Pluggable::Object;
use MooseX::Params::Validate qw( validated_hash );
use R2::Types qw(
    ArrayRef
    Bool
    HashRef
    Maybe
    NonEmptyStr
    PosInt
    PosOrZeroInt
    SearchPlugin
);
use URI::Escape qw( uri_escape_utf8 );

requires qw(
    _BuildCountSelectBase
    _BuildObjectSelectBase
    _BuildSearchedClasses
    _iterator_class
    _classes_returned_by_iterator
    _bind_params
    _build_title
);

with 'R2::Role::URIMaker';

has order_by => (
    is        => 'ro',
    isa       => NonEmptyStr,
    predicate => '_has_order_by',
);

has reverse_order => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
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

has pager => (
    is       => 'ro',
    isa      => Maybe ['Data::Pageset'],
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_pager',
);

has title => (
    is      => 'ro',
    isa     => NonEmptyStr,
    lazy    => 1,
    builder => '_build_title',
);

has includes_multiple_contact_types => (
    is      => 'ro',
    isa     => Bool,
    lazy    => 1,
    builder => '_build_includes_multiple_contact_types',
);

has result_type_string => (
    is      => 'ro',
    isa     => NonEmptyStr,
    lazy    => 1,
    builder => '_build_result_type_string',
);

has count => (
    is       => 'ro',
    isa      => PosOrZeroInt,
    init_arg => undef,
    lazy     => 1,
    builder  => '_build_count',
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
        has_restrictions  => 'count',
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
        _SearchedClassCount  => 'count',
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
}

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

sub _build_count {
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
    my $self   = shift;
    my $select = shift;

    if ( $self->has_restrictions() ) {
        $select->where('(');

        for my $plugin ( $self->_restrictions() ) {
            $plugin->apply_where_clauses($select);
        }

        $select->where(')');
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

sub _build_includes_multiple_contact_types {
    my $self = shift;

    return $self->_SearchedClassCount() > 1;
}

sub _build_result_type_string {
    my $self = shift;

    return 'contact' if $self->includes_multiple_contact_types();

    for my $type (qw( person household organization )) {
        my $class = 'R2::Schema::' . ucfirst $type;

        return $type if $self->_searches_class($class);
    }

    die 'wtf';
}

sub _build_pager {
    my $self = shift;

    return unless $self->limit();

    my $pager = Data::Pageset->new(
        {
            total_entries    => $self->count(),
            entries_per_page => $self->limit(),
            current_page     => $self->page(),
            pages_per_set    => 10,
            mode             => 'slide',
        }
    );

    return $pager;
}

sub new_uri {
    my $self = shift;
    my %p    = validated_hash(
        \@_,
        page          => { isa => PosInt,       optional => 1 },
        limit         => { isa => PosOrZeroInt, optional => 1 },
        order_by      => { isa => NonEmptyStr,  optional => 1 },
        reverse_order => { isa => Bool,         optional => 1 },
        MX_PARAMS_VALIDATE_ALLOW_EXTRA => 1,
    );

    my %query = map { $_ => delete $p{$_} }
        grep { defined $p{$_} } qw( page limit order_by reverse_order );

    delete $query{page} if $query{page} && $query{page} == 1;

    delete $query{order_by}
        if $query{order_by} eq
            $self->meta()->get_attribute('order_by')->default();

    delete $query{reverse_order} unless $query{reverse_order};

    return $self->uri( query => \%query, %p );
}

sub _restrictions_path_component {
    my $self = shift;

    return q{} unless $self->has_restrictions();

    my @params;
    for my $restriction ( $self->_restrictions() ) {
        for my $pair ( $restriction->uri_parameters() ) {
            push @params, join '=', map { uri_escape_utf8($_) } @{$pair};
        }
    }

    return join ';', sort @params;
}

sub domain { $_[0]->account()->domain() }

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
        my $self      = shift;
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
