package R2::Image;

use strict;
use warnings;

use Image::Magick;
use Path::Class ();
use R2::Schema::File;
use R2::Types;

use MooseX::StrictConstructor;
use MooseX::Params::Validate qw( validatep );


has 'file' =>
    ( is       => 'ro',
      isa      => 'R2::Type::FileIsImage',
      required => 1,
      handles  => [ 'path' ],
    );

sub resize
{
    my $self = shift;
    my ( $height, $width ) =
        validatep( \@_,
                   height => { isa => 'Int' },
                   width  => { isa => 'Int' },
                 );

    my $path = $self->file()->path();

    my $dir = $path->dir();
    my ( $name, $ext ) = $path->basename() =~ /(.+)\.([^.]+)$/;

    my $resized_name = $name . q{-} . $width . q{x} . $height . q{.} . $ext;

    my $resized_file = Path::Class::file( $dir, $resized_name );

    my $file = R2::Schema::File->new( filename => $resized_file->basename() );

    return R2::Image->new( file => $file )
        if $file;

    my $img = Image::Magick->new();
    $img->read( filename => $path );

    my $i_height = $img->get('height');
    my $i_width  = $img->get('width');

    if ( $height < $i_height
         ||
         $width  < $i_width
       )
    {
        my $height_r = $height / $i_height;
        my $width_r  = $width / $i_width;

        my $ratio = $height_r < $width_r ? $height_r : $width_r;

        $img->Scale( height => int( $i_height * $ratio ),
                     width  => int( $i_width * $ratio ),
                   );
    }

    $img->write( filename => $resized_file->stringify(),
                 quality  => $img->get('quality'),
                 type     => 'Palette',
               );

    $file =
        R2::Schema::File->insert
            ( filename   => $resized_file->basename(),
              contents   => scalar $resized_file->slurp(),
              mime_type  => $self->file()->mime_type(),
              account_id => $self->file()->account_id(),
            );

    return (ref $self)->new( file => $file );
}

__PACKAGE__->meta()->make_immutable();
no Moose;

1;
