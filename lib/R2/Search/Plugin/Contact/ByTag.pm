package R2::Search::Plugin::Contact::ByTag;

use Moose;
# intentionally not StrictConstructor

use namespace::autoclean;

use R2::Schema;
use R2::Types qw( SingleOrArrayRef NonEmptyStr );

with 'R2::Role::Search::Plugin';

has tags => (
    is  => 'ro',
    isa      => SingleOrArrayRef [NonEmptyStr],
    coerce   => 1,
    required => 1,
);

sub apply_where_clauses {
    my $self   = shift;
    my $select = shift;

    my $schema = R2::Schema->Schema();

    my @ph = 
    #<<<
    $select
        ->from ( $schema->tables( 'Tag', 'ContactTag' ) )
        ->from ( $schema->tables( 'ContactTag', 'Contact' ) )
        ->where( $schema->table('Tag')->column('tag'),
                 'IN', @{ $self->tags() } )
        ->and  ( $schema->table('Tag')->column('account_id'),
                 '=', $self->search()->account()->account_id() );
    #>>>

    return;
}

sub uri_parameters {
    my $self = shift;

    return map { [ 'tags', $_ ] } @{ $self->tags() };
}

__PACKAGE__->meta()->make_immutable();

1;
