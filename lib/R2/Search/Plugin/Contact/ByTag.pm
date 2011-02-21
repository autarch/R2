package R2::Search::Plugin::Contact::ByTag;

use Moose;
# intentionally not StrictConstructor

use namespace::autoclean;

use Lingua::EN::Inflect qw( WORDLIST );
use R2::Schema;
use R2::Types qw( SingleOrArrayRef NonEmptyStr );

with 'R2::Role::Search::Plugin';

has _tags => (
    traits   => ['Array'],
    isa      => SingleOrArrayRef [NonEmptyStr],
    coerce   => 1,
    init_arg => 'tags',
    required => 1,
    handles  => {
        _tags      => 'elements',
        _tag_count => 'count',
    },
);

sub apply_where_clauses {
    my $self   = shift;
    my $select = shift;

    my $schema = R2::Schema->Schema();

    my $subselect = R2::Schema->SQLFactoryClass()->new_select();

    #<<<
    $subselect
        ->select( $schema->table('ContactTag')->column('contact_id') )
        ->from  ( $schema->tables( 'Tag', 'ContactTag' ) )
        ->from  ( $schema->tables( 'ContactTag', 'Contact' ) )
        ->where ( $schema->table('Tag')->column('tag'),
                  'IN', $self->_tags() )
        ->and   ( $schema->table('Tag')->column('account_id'),
                  '=', $self->search()->account()->account_id() );
    #>>>

    $select->where(
        $schema->table('Contact')->column('contact_id'),
        'IN', $subselect
    );

    return;
}

sub uri_parameters {
    my $self = shift;

    return map { [ 'tags', $_ ] } $self->_tags();
}

sub _build_description {
    my $self = shift;

    my $desc = 'are tagged with ';
    $desc .=
          $self->_tag_count() == 2 ? 'either '
        : $self->_tag_count() >= 3 ? 'any one of '
        :                            q{};

    $desc .= WORDLIST(
        ( map {qq{"$_"}} $self->_tags() ),
        { conj => 'or' }
    );

    return $desc;
}

__PACKAGE__->meta()->make_immutable();

1;
