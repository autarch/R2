package R2::Web::Javascript;

use strict;
use warnings;
use namespace::autoclean;

use JavaScript::Minifier::XS qw( minify );
use JSAN::ServerSide 0.04;
use Path::Class;
use R2::Config;
use R2::Types qw( Bool );

use Moose;

has squish => (
    is      => 'ro',
    isa     => Bool,
    default => sub { R2::Config->instance()->is_production() },
);

with 'R2::Role::Web::CombinedStaticFiles';

sub _build_header {
    return q[var JSAN = { "use": function () {} };] . "\n";
}

sub _build_files {
    my $dir = dir( R2::Config->instance()->share_dir(), 'js-source' );

    # Works around an error that comes from JSAN::Parse::FileDeps
    # attempting to assign $_, which is somehow read-only.
    local $_;
    my $js = JSAN::ServerSide->new(
        js_dir => $dir->stringify(),

        # This is irrelevant, as we won't be
        # serving the individual files.
        uri_prefix => '/',
    );

    $js->add('R2');

    return [
        $dir->file('jquery-1.4.4.js'),
        $dir->file('jquery-ui-1.8.9.custom.min.js'),
        $dir->file('jquery-timepickr-0.7.0a.js'),
        map { file($_) } $js->files()
    ];
}

sub _build_target_file {
    my $js_dir = dir( R2::Config->instance()->var_lib_dir(), 'js' );

    $js_dir->mkpath( 0, 0755 );

    return file( $js_dir, 'r2-combined.js' );
}

sub _squish {
    my $self = shift;
    my $code = shift;

    return $code unless $self->squish();

    return $code;
    # XXX - minifier breaks against jquery?
#    return minify($code);
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Combines and minifies Javascript source files
