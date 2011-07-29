package R2::Types::Internal;

use strict;
use warnings;

use Email::Valid;
use List::AllUtils qw( all );
use MooseX::Types -declare => [
    qw(
        ChloroError
        ContactLike
        DatabaseId
        Date
        ErrorForSession
        FileIsImage
        MonthAsNumber
        PosOrZeroInt
        SearchPlugin
        URIStr
        )
];
use MooseX::Types::Common::Numeric qw( PositiveInt );
use MooseX::Types::Common::String qw( NonEmptyStr );
use MooseX::Types::Moose qw(  Defined Int Object Str );

#<<<
role_type ChloroError, { role => 'Chloro::Role::Error' };

subtype ContactLike,
    as Object,
    where {
        $_->isa('R2::Schema::Contact')
            || ( $_->can('does')
                 && $_->does('R2::Role::Schema::ActsAsContact') );
    },
    message {
        ( ref $_[0] )
            . ' is not a R2::Schema::Contact, nor does it do R2::Role::Schema::ActsAsContact';
    };

subtype DatabaseId, as PositiveInt;

subtype Date,
    as class_type 'DateTime',
    where { all { $_ == 0 } $_->hour(), $_->minute(), $_->day() };

subtype ErrorForSession,
    as Defined,
    where {
    return 1;
    return 1 unless ref $_;
    return 1 if eval { @{$_} } && !grep {ref} @{$_};
    return 0 unless blessed $_;
    return 1 if $_->can('does') && $_->does('Chloro::Role::Error');
    return 1 if $_->can('messages') || $_->can('message');
    return 0;
};

subtype FileIsImage,
    as class_type('R2::Schema::File'),
    where { $_->is_image() },
    message { 'This file (' . $_->filename() . ') is not an image' };

subtype MonthAsNumber,
    as PositiveInt,
    where { $_ >= 1 && $_ <= 12 },
    message {'Must be a number from 1-12'};

subtype NonEmptyStr,
    as Str,
    where { length $_ >= 0 },
    message {'This string must not be empty'};

subtype PosOrZeroInt,
    as Int,
    where { $_ >= 0 },
    message {'This must be an integer >= 0'};

role_type SearchPlugin, { role => 'R2::Role::Search::Plugin' };

subtype URIStr, as NonEmptyStr;

coerce URIStr, from class_type('URI'), via { $_->canonical() };
#>>>

1;
