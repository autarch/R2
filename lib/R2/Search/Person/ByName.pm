package R2::Search::Person::ByName;

use strict;
use warnings;

use R2::Schema;
use R2::Types qw( NonEmptyStr );

use Moose;

extends 'R2::Search::Person';

has 'name' => (
    is  => 'ro',
    isa => NonEmptyStr,
);

my $Schema = R2::Schema->Schema();

sub _apply_where_clauses {
    my $self   = shift;
    my $select = shift;

    # The theory is that if there's more than 2 parts then it's
    # probably a last name with a space in it, as opposed to someone
    # giving us first, middle & last names.
    #
    # Also note that this would completely break for names written in
    # Chinese characters, which are written without spaces.
    my @parts = split /\s+/, lc $self->name(), 2;
    if ( @parts == 1 ) {
        $select->where('(')->where(
            Fey::Literal::Function->new(
                'LOWER', $Schema->table('Person')->column('first_name')
            ),
            'LIKE',
            lc $parts[0] . '%'
            )->where('or')->where(
            Fey::Literal::Function->new(
                'LOWER', $Schema->table('Person')->column('last_name')
            ),
            'LIKE',
            $parts[0] . '%'
            )->where(')');
    }
    else {
        $select->where(
            Fey::Literal::Function->new(
                'LOWER', $Schema->table('Person')->column('first_name')
            ),
            'LIKE',
            $parts[0] . '%'
            )->where(
            Fey::Literal::Function->new(
                'LOWER', $Schema->table('Person')->column('last_name')
            ),
            'LIKE',
            $parts[1] . '%'
            );
    }
}

__PACKAGE__->meta()->make_immutable();

no Moose;

1;
