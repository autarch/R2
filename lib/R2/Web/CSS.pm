package R2::Web::CSS;

use strict;
use warnings;
use namespace::autoclean;

use autodie qw( :all );
use CSS::Minifier qw( minify );
use File::Slurp qw( read_file );
use File::Temp;
use File::Which qw( which );
use Path::Class;
use R2::Config;
use R2::Types qw( Str );

use Moose;

with 'R2::Role::Web::CombinedStaticFiles';

has sass_path => (
    is      => 'ro',
    isa     => Str,
    builder => '_build_sass_path',
);

sub _build_files {
    my $dir = dir( R2::Config->instance()->share_dir(), 'css-source' );

    return [
        sort
            grep {
                  !$_->is_dir()
                && $_->basename() =~ /^\d+/
                && $_->basename()
                =~ /\.s?css$/
            } $dir->children()
    ];
}

sub _build_target_file {
    my $css_dir = dir( R2::Config->instance()->var_lib_dir(), 'css' );

    $css_dir->mkpath( 0, 0755 );

    return file( $css_dir, 'r2-combined.css' );
}

sub _squish {
    my $self = shift;
    my $css  = shift;

    return $css;
    return minify( input => $css );
}

sub _process {
    my $self = shift;
    my $file = shift;

    my $filename = $file->stringify();

    # We need to delay unlinking of the temp file until after it is read.
    my $temp;
    if ( $filename =~ /\.scss$/ ) {
        $temp = File::Temp->new();
        system( $self->sass_path(), '-C', $filename, $temp->filename() );
        $filename = $temp->filename();
    }

    return scalar read_file($filename);
}

sub _build_sass_path {
    my $self = shift;

    my $bin = which('sass');
    return $bin if $bin;

    $bin = '/var/lib/gems/1.8/bin/sass';
    return $bin if -x $bin;

    die "Cannot find sass in your path";
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Combines and minifies CSS source files
