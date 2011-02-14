package R2::Search::Plugin::Contact::ByTag;

use Moose;
# intentionally not StrictConstructor

use namespace::autoclean;

use R2::Schema;
use R2::Types qw( Int );

with 'R2::Role::Search::Plugin';

has 'tag_id' => (
    is  => 'ro',
    isa => Int,
);

sub apply_where_clauses {
    my $self   = shift;
    my $select = shift;

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->from ( $schema->tables( 'ContactTag', 'Contact' ) )
        ->where( $schema->table('ContactTag')->column('tag_id'),
                 '=', $self->tag_id() );
    #>>>

    return;
}

__PACKAGE__->meta()->make_immutable();

1;
