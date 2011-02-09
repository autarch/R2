package R2::Search::Contact::ByTag;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;
use R2::Types qw( Int );

use Moose;

extends 'R2::Search::Contact';

has 'tag_id' => (
    is  => 'ro',
    isa => Int,
);

my $Schema = R2::Schema->Schema();

sub _apply_where_clauses {
    my $self   = shift;
    my $select = shift;

    super();

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
