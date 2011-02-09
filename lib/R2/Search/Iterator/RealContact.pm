package R2::Search::Iterator::RealContact;

use Moose;
use MooseX::StrictConstructor;

use namespace::autoclean;

extends 'Fey::Object::Iterator::FromSelect';

override _get_next_result => sub {
    my $self = shift;

    my $result = super();

    return [ grep { defined } @{$result} ];
};

__PACKAGE__->meta()->make_immutable();

1;
