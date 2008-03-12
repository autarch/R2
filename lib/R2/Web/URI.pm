package R2::Web::URI;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( static_uri );

use R2::Util qw( string_is_empty );


sub static_uri
{
    my $path = shift;

    my $prefix = R2::Config->new()->static_path_prefix();

    $path = q{/} . $prefix . $path
        if $prefix && ! string_is_empty( $path );

    return $path;
}

1;
