package R2::Web::Javascript;

use strict;
use warnings;

use JavaScript::Squish;
use JSAN::ServerSide 0.04;
use Path::Class;
use R2::Config;

use Moose;

extends 'R2::Web::CombinedStaticFiles';


sub _files
{
    my $dir = dir( R2::Config->new()->share_dir(), 'js-source' );

    my $js =
        JSAN::ServerSide->new( js_dir     => $dir->stringify(),
                               # This is irrelevant, as we won't be
                               # serving the individual files.
                               uri_prefix => '/',
                             );

    $js->add('R2');

    return [ map { file($_) } $js->files() ];
}

sub _target_file
{
    my $js_dir = File::Spec->catdir( R2::Config->new()->var_lib_dir(), 'js' );
    File::Path::mkpath( $js_dir, 0, 0755 )
        unless -d $js_dir;

    return file( $js_dir, 'r2-combined.js' );
}

{
    my @Exceptions = ( qr/\@cc_on/,
                       qr/\@if/,
                       qr/\@end/,
                     );

    sub _squish
    {
        my $self = shift;
        my $code = shift;

        return $code
            unless R2::Config->new()->is_production();

        return JavaScript::Squish->squish( \$code,
                                           remove_comments_exceptions => \@Exceptions,
                                         );
    }
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
