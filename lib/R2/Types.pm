package R2::Types;

use strict;
use warnings;

use Email::Valid;
use Moose::Util::TypeConstraints;


subtype 'R2::Type::EmailAddress'
    => as 'Str'
    => where { Email::Valid->valid($_) }
    => message { "$_ is not a valid email address" };

subtype 'R2::Type::URIPath'
    => as 'Str'
    => where { length $_ && $_ =~ m{^/} }
    => message { "This path ($_) is either empty or does not start with a slash (/)" };

subtype 'R2::Type::FileIsImage'
    => as class_type('R2::Schema::File')
    => where { $_->is_image() }
    => message { 'This file is not an image' };

no Moose::Util::TypeConstraints;

1;

