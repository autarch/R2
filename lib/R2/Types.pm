package R2::Types;

use strict;
use warnings;
use namespace::autoclean;

use Moose::Util::TypeConstraints;
use MooseX::Types::Moose qw( ArrayRef );
use Sub::Install;

use base 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from(
    qw(
        MooseX::Types::Common::String
        MooseX::Types::Moose
        MooseX::Types::Path::Class
        R2::Types::Internal
        )
);

sub import {
    my $class = shift;
    my %types = map { $_ => 1 } @_;

    my $caller = caller;

    if ( delete $types{SingleOrArrayRef} ) {
        Sub::Install::install_sub(
            {
                code => \&SingleOrArrayRef,
                into => $caller,
            }
        );
    }

    @_ = ( $class, keys %types );

    my $super = MooseX::Types::Combine->can('import');

    goto &{$super};
}

# Without a prototype this ends up eating everything passed to has() that
# comes after the type declaration
sub SingleOrArrayRef ($) {
    my $param = $_[0]->[0];

    my $name = 'R2::Types::Internal::SingleOrArrayRefOf::' . $param->name();

    return $name if find_type_constraint($name);

    #<<<
    subtype $name,
        as ArrayRef [$param],
        where { @{$_} >= 1 };

    coerce $name,
        from $param,
        via { [ $_[0] ] };
    #>>>
    return $name;
}

1;
