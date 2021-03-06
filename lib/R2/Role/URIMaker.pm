package R2::Role::URIMaker;

use strict;
use warnings;
use namespace::autoclean;

use MooseX::Params::Validate qw( validated_hash );
use R2::Util qw( string_is_empty );
use R2::URI qw( dynamic_uri );

use Moose::Role;

#requires_attr_or_method (??) 'domain';

requires '_base_uri_path';

{
    my %spec = (
        view      => { isa => 'Str',     optional => 1 },
        fragment  => { isa => 'Str',     optional => 1 },
        query     => { isa => 'HashRef', default  => {} },
        with_host => { isa => 'Bool',    default  => 0 },
    );

    sub uri {
        my $self = shift;
        my %p = validated_hash( \@_, %spec );

        my $path = $self->_base_uri_path();
        $path .= q{/} . $p{view}
            unless string_is_empty( $p{view} );

        $self->_make_uri(
            path      => $path,
            fragment  => $p{fragment},
            query     => $p{query},
            with_host => $p{with_host},
        );
    }
}

sub _make_uri {
    my $self = shift;
    my %p    = @_;

    delete $p{fragment}
        if string_is_empty( $p{fragment} );

    return dynamic_uri(
        $self->_host_params_for_uri( delete $p{with_host} ),
        %p,
    );
}

sub _host_params_for_uri {
    my $self = shift;

    return unless $_[0];

    return %{ $self->domain()->uri_params() };
}

1;
