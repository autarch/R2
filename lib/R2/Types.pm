package R2::Types;

use strict;
use warnings;

use base 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from( qw( R2::Types::Internal MooseX::Types::Moose ) );

1;
