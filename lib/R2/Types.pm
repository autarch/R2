package R2::Types;

use strict;
use warnings;

use Email::Valid;
use Moose::Util::TypeConstraints;


subtype 'R2.Type.FileIsImage'
    => as class_type('R2::Schema::File')
    => where { $_->is_image() }
    => message { 'This file (' . $_->filename() . ') is not an image' };

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

subtype 'R2.Type.ErrorForSession'
    => as 'Value'
    => where { return 1 unless ref $_[0];
               return 1 if eval { @{ $_[0] } } && ! grep { ref } @{ $_[0] };
               return 0 unless blessed $_[0];
               return 1 if $_[0]->can('messages') || $_[0]->can('message');
               return 0;
             };

subtype 'R2.Type.URIStr'
    => as 'R2.Type.NonEmptyStr';

coerce 'R2.Type.URIStr'
    => from class_type('URI')
    => via { $_->canonical() };

no Moose::Util::TypeConstraints;

1;

