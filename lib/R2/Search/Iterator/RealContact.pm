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

override _new_object => sub {
    my $self  = shift;
    my $class = shift;
    my $attr  = shift;

    # There will always be one defined element (_from_query = 1)
    return undef unless ( grep {defined} values %{$attr} ) > 1;

    return super();
};

__PACKAGE__->meta()->make_immutable();

1;
