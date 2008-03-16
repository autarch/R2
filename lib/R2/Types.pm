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
    => where { defined $_ && length $_ && $_ =~ m{^/} }
    => message { my $path = defined $_ ? $_ : '';
                 "This path ($path) is either empty or does not start with a slash (/)" };
