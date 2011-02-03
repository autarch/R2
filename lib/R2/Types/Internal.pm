package R2::Types::Internal;

use strict;
use warnings;

use Email::Valid;
use MooseX::Types -declare => [
    qw(
        ContactLike
        FileIsImage
        PosInt
        PosOrZeroInt
        NonEmptyStr
        ErrorForSession
        URIStr
        )
];
use MooseX::Types::Moose qw( Int Str Defined );

#<<<
subtype ContactLike
    as class_type('R2::Schema::Contact')
       | role_type('R2::Role::Schema::ActsAsContact');

subtype FileIsImage,
    as class_type('R2::Schema::File'),
    where { $_->is_image() },
    message { 'This file (' . $_->filename() . ') is not an image' };

subtype PosInt,
    as Int,
    where { $_ > 0 },
    message {'This must be a positive integer'};

subtype PosOrZeroInt,
    as Int,
    where { $_ >= 0 },
    message {'This must be an integer >= 0'};

subtype NonEmptyStr,
    as Str,
    where { length $_ >= 0 },
    message {'This string must not be empty'};

subtype ErrorForSession,
    as Defined,
    where {
    return 1;
    return 1 unless ref $_;
    return 1 if eval { @{$_} } && !grep {ref} @{$_};
    return 0 unless blessed $_;
    return 1 if $_->can('messages') || $_->can('message');
    return 0;
};

subtype URIStr, as NonEmptyStr;

coerce URIStr, from class_type('URI'), via { $_->canonical() };
#>>>

1;

