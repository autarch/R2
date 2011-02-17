package R2::Search::Plugin::Contact::ByTag;

use Moose;
# intentionally not StrictConstructor

use namespace::autoclean;

use R2::Schema;
use R2::Types qw( SingleOrArrayRef DatabaseId );

with 'R2::Role::Search::Plugin';

has tag_ids => (
    is  => 'ro',
    isa      => SingleOrArrayRef [DatabaseId],
    coerce   => 1,
    required => 1,
);

sub apply_where_clauses {
    my $self   = shift;
    my $select = shift;

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->from ( $schema->tables( 'ContactTag', 'Contact' ) )
        ->where( $schema->table('ContactTag')->column('tag_id'),
                 'IN', @{ $self->tag_ids() } );
    #>>>

    return;
}

sub uri_parameters {
    my $self = shift;

    return map { [ 'tag_ids', $_ ] } @{ $self->tag_ids() };
}

__PACKAGE__->meta()->make_immutable();

1;
