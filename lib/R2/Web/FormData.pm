package R2::Web::FormData;

use strict;
use warnings;
use namespace::autoclean;

use Moose;
use MooseX::StrictConstructor;

has 'sources' => (
    is       => 'ro',
    isa      => 'ArrayRef[HashRef|Object]',
    required => 1,
);

has 'prefix' => (
    is      => 'ro',
    isa     => 'Str',
    default => q{},
);

has 'suffix' => (
    is      => 'ro',
    isa     => 'Str',
    default => q{},
);

sub has_sources {
    return scalar @{ $_[0]->sources() };
}

sub param {
    my $self  = shift;
    my $param = shift;

    if ( my $p = $self->prefix() ) {
        # Don't want to turn phone_number_type_id into type_id
        $param =~ s/^\Q$p\E_(?!type)//;
    }

    if ( my $s = $self->suffix() ) {
        $param =~ s/\Q$s\E$//;
    }

    foreach my $s ( @{ $self->sources() } ) {
        if ( blessed $s ) {
            return $s->$param() if $s->can($param);
        }
        else {
            return $s->{$param} if exists $s->{$param};
        }
    }

    return;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents data for filling in forms

