package R2::Role::Web::Form;

use strict;
use warnings;
use namespace::autoclean;

use R2::Util qw( string_is_empty );

use Moose::Role;

has user => (
    is       => 'ro',
    isa      => 'R2::Schema::User',
    required => 1,
);

before update_fields => sub {
    my $self = shift;

    for my $field ( grep { $_->type() eq 'Date' } $self->fields() ) {
        $field->format( $self->user()->date_format_for_jquery() );
    }
};

around value => sub {
    my $orig = shift;
    my $self = shift;

    my $val = $self->$orig(@_);

    delete $val->{$_} for grep { string_is_empty( $val->{$_} ) } keys %{$val};

    return $val;
};

1;
