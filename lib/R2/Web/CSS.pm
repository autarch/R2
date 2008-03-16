package R2::Web::CSS;

use strict;
use warnings;

use CSS::Minifier qw( minify );
use Path::Class;
use R2::Config;

use Moose;

extends 'R2::Web::CombinedStaticFiles';


sub _files
{
    my $dir = dir( R2::Config->new()->share_dir(), 'css-source' );

    return [ sort
             grep { $_->isa('Path::Class::File') && $_->basename() =~ /\.css$/ }
             $dir->children() ];
}

sub _target_file
{
    my $css_dir = File::Spec->catdir( R2::Config->new()->var_lib_dir(), 'css' );
    File::Path::mkpath( $css_dir, 0, 0755 )
        unless -d $css_dir;

    return file( $css_dir, 'r2-combined.css' );
}

sub _squish
{
    my $self = shift;
    my $css  = shift;

    return minify( input => $css );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
