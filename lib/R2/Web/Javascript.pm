package R2::Web::Javascript;

use strict;
use warnings;
use namespace::autoclean;

use JavaScript::Squish;
use JSAN::ServerSide 0.04;
use Path::Class;
use R2::Config;

use Moose;

extends 'R2::Web::CombinedStaticFiles';

has '+header' => (
    default => q[var JSAN = { "use": function () {} };] . "\n",
);

sub _files {
    my $dir = dir( R2::Config->new()->share_dir(), 'js-source' );

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

    return [ map { file($_) } $js->files() ];
}

sub _target_file {
    my $js_dir = dir( R2::Config->new()->var_lib_dir(), 'js' );

    $js_dir->mkpath( 0, 0755 );

    return file( $js_dir, 'r2-combined.js' );
}

{
    my @Exceptions = (
        qr/\@cc_on/,
        qr/\@if/,
        qr/\@end/,
    );

    sub _squish {
        my $self = shift;
        my $code = shift;

        return $code
            unless R2::Config->instance()->is_production();

        return JavaScript::Squish->squish(
            \$code,
            remove_comments_exceptions => \@Exceptions,
        );
    }
}

__PACKAGE__->meta()->make_immutable();

1;
