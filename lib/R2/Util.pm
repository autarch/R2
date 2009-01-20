package R2::Util;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( string_is_empty studly_to_calm );


sub string_is_empty
{
    return 1 if ! defined $_[0] || ! length $_[0];
    return 0;
}

sub studly_to_calm
{
    my $studly = shift;

    return join q{_}, map { lc } ( $studly =~ /([A-Z][a-z]+)/g );
}

1;
