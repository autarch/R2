package R2::Web::Javascript;

use strict;
use warnings;

use JavaScript::Squish;
use JSAN::ServerSide 0.04;
use Path::Class;

use MooseX::Singleton;

extends 'R2::Web::CombinedStaticFiles';


sub _files
{
    my $dir = dir( R2::Config->ShareDir(), 'js-source' );

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
    my $js_dir = File::Spec->catdir( R2::Config->VarLibDir(), 'js' );
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

        return JavaScript::Squish->squish( \$code,
                                           remove_comments_exceptions => \@Exceptions,
                                         );
    }
}

make_immutable;

no Moose;

1;
