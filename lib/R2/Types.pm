package R2::Types;

use strict;
use warnings;

use base 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from(
    qw(
        MooseX::Types::Common::String
        MooseX::Types::Moose
        MooseX::Types::Path::Class
        R2::Types::Internal
        )
);

1;
