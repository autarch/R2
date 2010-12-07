package R2::Web::CSS;

use strict;
use warnings;
use namespace::autoclean;

use CSS::Minifier qw( minify );
use Path::Class;
use R2::Config;

use Moose;

extends 'R2::Web::CombinedStaticFiles';

sub _files {
    my $dir = dir( R2::Config->new()->share_dir(), 'css-source' );

    return [
        sort
            grep {
                  !$_->is_dir()
                && $_->basename() =~ /^\d+/
                && $_->basename()
                =~ /\.css$/
            } $dir->children()
    ];
}

sub _target_file {
    my $css_dir = dir( R2::Config->new()->var_lib_dir(), 'css' );

    $css_dir->mkpath( 0, 0755 );

    return file( $css_dir, 'r2-combined.css' );
}

sub _squish {
    my $self = shift;
    my $css  = shift;

    return minify( input => $css );
}

__PACKAGE__->meta()->make_immutable();

1;
