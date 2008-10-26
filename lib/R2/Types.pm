package R2::Types;

use strict;
use warnings;

use Email::Valid;
use Moose::Util::TypeConstraints;


subtype 'R2.Type.FileIsImage'
    => as class_type('R2.Schema.File')
    => where { $_->is_image() }
    => message { 'This file is not an image' };

subtype 'R2.Type.PosInt'
    => as 'Int'
    => where { $_ > 0 }
    => message { 'This must be a positive integer' };

subtype 'R2.Type.PosOrZeroInt'
    => as 'Int'
    => where { $_ >= 0 }
    => message { 'This must be an integer >= 0' };

subtype 'R2.Type.NonEmptyStr'
    => as 'Str'
    => where { length $_ >= 0 }
    => message { 'This string must not be empty' };

no Moose::Util::TypeConstraints;

1;

