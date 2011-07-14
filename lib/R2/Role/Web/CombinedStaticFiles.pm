package R2::Role::Web::CombinedStaticFiles;

use strict;
use warnings;
use namespace::autoclean;

use autodie;
use DateTime;
use File::Copy qw( move );
use File::Slurp qw( read_file );
use File::Temp qw( tempfile );
use JSAN::ServerSide 0.04;
use List::AllUtils qw( all );
use Path::Class;
use R2::Config;
use R2::Types qw( ArrayRef File Str );
use R2::Util qw( string_is_empty );
use Time::HiRes;

use Moose::Role;

has files => (
    is      => 'ro',
    isa     => ArrayRef [File],
    lazy    => 1,
    builder => '_build_files',
);

has target_file => (
    is      => 'ro',
    isa     => File,
    lazy    => 1,
    builder => '_build_target_file',
);

has header => (
    is      => 'ro',
    isa     => Str,
    builder => '_build_header',
);

requires qw( _squish );

sub _build_header {
    return q{};
}

sub create_single_file {
    my $self   = shift;
    my $squish = shift;

    my $target = $self->target_file();

    my $target_mod = -f $target ? $target->stat()->mtime() : 0;

    return
        unless grep { $_->stat()->mtime() >= $target_mod }
            @{ $self->files() };

    my ( $fh, $tempfile ) = tempfile( UNLINK => 0 );

    print {$fh} $self->_create_content($squish);

    close $fh;

    move( $tempfile => $target )
        or die "Cannot move $tempfile => $target: $!";
}

sub _create_content {
    my $self = shift;
    my $squish = shift;

    my $now = DateTime->now(
        time_zone => 'local',
    )->strftime('%Y-%m-%d %H:%M:%S.%{nanosecond} %{time_zone_long_name}');

    my $content = "/* Generated at $now */\n\n";

    my $header = $self->header();
    $content .= $header
        unless string_is_empty($header);

    for my $file ( @{ $self->files() } ) {
        $content .= "\n\n/* $file */\n\n";

        if ($squish) {
            $content
                .= eval { $self->_squish( $self->_process($file) ) } || q{};
            if ( my $e = $@ ) {
                die "Error squishing $file: $e\n";
            }
        }
        else {
            $content .= $self->_process($file);
        }
    }

    return $content;
}

sub _process {
    my $self = shift;
    my $file = shift;

    return scalar read_file( $file->stringify() );
}

1;

# ABSTRACT: Provides common behavior for combining and minifying JS or CSS
