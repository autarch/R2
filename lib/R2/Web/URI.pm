package R2::Web::URI;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( dynamic_uri static_uri );

use List::MoreUtils qw( all );
use R2::Util qw( string_is_empty );
use URI::FromHash ();


{
    my $Prefix = R2::Config->instance()->dynamic_path_prefix() || '';

    sub dynamic_uri
    {
        my %p = @_;

        $p{path} = _prefix_path( $Prefix, $p{path} );

        return URI::FromHash::uri(%p);
    }
}

{
    my $Prefix = R2::Config->new()->static_path_prefix() || '';

    sub static_uri
    {
        my $path = shift;

        return _prefix_path( $Prefix, $path );
    }
}

sub _prefix_path
{
    my $prefix = shift;
    my $path   = shift;

    return '/'
        if all { string_is_empty($_) } $prefix, $path;

    $path = $prefix . ( $path || '' );

    return $path;
}

1;
