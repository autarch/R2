package R2::Search;

use strict;
use warnings;

use R2::Types;

use Moose;

has 'limit' =>
    ( is      => 'ro',
      isa     => 'R2.Type.PosOrZeroInt',
      default => 0,
    );

has 'page' =>
    ( is      => 'ro',
      isa     => 'R2.Type.PosInt',
      default => 1,
    );

sub _apply_limit
{
    my $self   = shift;
    my $select = shift;

    return unless $self->limit();

    my @limit = $self->limit();
    push @limit, ( $self->page() - 1 ) * $self->limit();

    $select->limit(@limit);
}

__PACKAGE__->meta()->make_immutable();

1;
