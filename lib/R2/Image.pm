package R2::Image;

use strict;
use warnings;

use Image::Magick;
use Path::Class ();
use R2::Schema::File;
use R2::Types;

use Moose;
use MooseX::StrictConstructor;
use MooseX::Params::Validate qw( validatep );


has 'file' =>
    ( is       => 'ro',
      isa      => 'R2::Type::FileIsImage',
      required => 1,
      handles  => [ 'path', 'uri' ],
    );

sub resize
{
    my $self = shift;
    my ( $height, $width ) =
        validatep( \@_,
                   height => { isa => 'Int' },
                   width  => { isa => 'Int' },
                 );

    my $dimensions = $width . q{x} . $height;
    my $unique_name = $self->file()->file_id() . q{-} . $dimensions;

    my $file = eval { R2::Schema::File->new( unique_name => $unique_name ) };

    return R2::Image->new( file => $file )
        if $file;

    my $img = Image::Magick->new();
    $img->read( filename => $self->file()->path() );

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

    my $resized_file =
        $self->file()->path()->dir()->file
            ( $self->file()->extensionless_basename()
              . q{-}
              . $dimensions
              . q{.} . $self->file()->extension() );

    $img->write( filename => $resized_file->stringify(),
                 quality  => $img->get('quality'),
                 type     => 'Palette',
               );

    $file =
        R2::Schema::File->insert
            ( filename    => $resized_file->basename(),
              contents    => scalar $resized_file->slurp(),
              mime_type   => $self->file()->mime_type(),
              account_id  => $self->file()->account_id(),
              unique_name => $unique_name,
            );

    return (ref $self)->new( file => $file );
}

no Moose;

__PACKAGE__->meta()->make_immutable();

1;
