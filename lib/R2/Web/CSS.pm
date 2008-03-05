package R2::Web::CSS;

use strict;
use warnings;

use CSS::Minifier qw( minify );
use Path::Class;

use MooseX::Singleton;

extends 'R2::Web::CombinedStaticFiles';


sub _files
{
    my $dir = dir( R2::Config->ShareDir(), 'css-source' );

    return [ sort
             grep { $_->isa('Path::Class::File') && $_->basename() =~ /\.css$/ }
             $dir->children() ];
}

sub _target_file
{
    my $css_dir = File::Spec->catdir( R2::Config->VarLibDir(), 'css' );
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

make_immutable;

no Moose;

1;
