package R2::Search::Plugin::Contact::ByName;

use Moose;

# intentionally not StrictConstructor

use namespace::autoclean;

use Lingua::EN::Inflect qw( WORDLIST );
use List::AllUtils qw( uniq );
use R2::Schema;
use R2::Types qw( NonEmptyStr SingleOrArrayRef );

with 'R2::Role::Search::Plugin';

has _names => (
    traits   => ['Array'],
    isa      => SingleOrArrayRef [NonEmptyStr],
    coerce   => 1,
    init_arg => 'names',
    required => 1,
    handles  => {
        _names      => 'elements',
        _name_count => 'count',
    },
);

override BUILDARGS => sub {
    my $self = shift;
    my $p    = super();

    $p->{names} = delete $p->{name}
        if $p->{name};

    return $p;
};

my $Schema = R2::Schema->Schema();

sub apply_where_clauses {
    my $self   = shift;
    my $select = shift;

    my @names = uniq map {lc} $self->_names();

    for my $name (@names) {
        $select->where('or') if $name ne $names[0];
        $self->_apply_where_clauses( $select, $name );
    }

    return;
}

sub _apply_where_clauses {
    my $self   = shift;
    my $select = shift;
    my $name   = shift;

    $select->where('(');

    $self->_person_where_clause( $select, $name )
        if $self->search()->searches_class('Person');

    $select->where('or')
        if $self->search()->searches_class( 'Person', 'Household' );

    $select->where(
        $Schema->table('Household')->column('name'),
        'LIKE',
        $name . '%'
    ) if $self->search()->searches_class('Household');

    $select->where('or')
        if $self->search()->searches_class( 'Household', 'Organization' );

    $select->where(
        $Schema->table('Organization')->column('name'),
        'LIKE',
        $name . '%'
    ) if $self->search()->searches_class('Organization');

    $select->where(')');
}

sub _person_where_clause {
    my $self   = shift;
    my $select = shift;
    my $name   = shift;

    # The theory is that if there's more than 2 parts then it's
    # probably a last name with a space in it, as opposed to someone
    # giving us first, middle & last names.
    #
    # Also note that this would completely break for names written in
    # Chinese characters, which are written without spaces.
    my @parts = split /\s+/, $name, 2;

    if ( @parts == 1 ) {
        #<<<
        $select
            ->where('(')
            ->where( $Schema->table('Person')->column('first_name'),
                     'LIKE',
                     lc $parts[0] . '%' )
            ->where('or')
            ->where( $Schema->table('Person')->column('last_name'),
                     'LIKE',
                     $parts[0] . '%' )
            ->where(')');
        #>>>
    }
    else {
        #<<<
        $select
            ->where( $Schema->table('Person')->column('first_name'),
                     'LIKE',
                     $parts[0] . '%' )
            ->where( $Schema->table('Person')->column('last_name'),
                     'LIKE',
                     $parts[1] . '%' );
        #>>>
    }
}

sub uri_parameters {
    my $self = shift;

    return map { [ 'name', $_ ] } $self->_names();
}

sub _build_description {
    my $self = shift;

    my $desc = 'have a name matching ';
    $desc .=
          $self->_name_count() == 2 ? 'either '
        : $self->_name_count() == 3 ? 'any one of '
        :                             q{};

    $desc .= WORDLIST(
        ( map {qq{"$_"}} $self->_names() ),
        { conj => 'or' }
    );

    return $desc;
}

__PACKAGE__->meta()->make_immutable();

1;
