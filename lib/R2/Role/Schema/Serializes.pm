package R2::Role::Schema::Serializes;

use strict;
use warnings;
use namespace::autoclean;

use JSON ();
use R2::Types qw( ArrayRef Str );

use MooseX::Role::Parameterized;

parameter skip => (
    isa => ArrayRef [Str],
    default => sub { [] },
);

parameter add => (
    isa => ArrayRef [Str],
    default => sub { [] },
);

role {
    my $p     = shift;
    my %extra = @_;

    my %skip = map { $_ => 1 } @{ $p->skip() };

    my %map;
    my %bools;

    for my $attr ( $extra{consumer}->get_all_attributes() ) {

        next if $skip{ $attr->name() };
        next if $attr->name() =~ /_raw$/;

        if ( $attr->name() =~ /^(?:is|can)_/ ) {
            $bools{ $attr->name() } = 1;
        }

        # We only want to serialize data from the class's the associated table
        if (   $attr->name() =~ /_date(?:time)?$/
            && $attr->isa('Fey::Meta::Attribute::FromInflator') ) {

            $map{ $attr->name() } = $attr->raw_attribute()->name();
        }
        elsif ($attr->isa('Fey::Meta::Attribute::FromColumn')
            || $attr->isa('Fey::Meta::Attribute::FromInflator') ) {

            $map{ $attr->name() } = $attr->name();
        }
    }

    my @add = @{ $p->add() };

    method serialize => sub {
        my $self = shift;

        my %ser = (
            map {
                my $meth = $map{$_} || $_;
                my $val
                    = $bools{$_}
                    ? ( $self->$meth() ? JSON::true() : JSON::false() )
                    : $self->$meth();
                ( $_ => $val );
                } @add,
            keys %map
        );

        $ser{uri} = $self->uri()
            if $self->can('uri');

        return \%ser;
    };
};

1;
