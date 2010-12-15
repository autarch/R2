package R2::Image;

use strict;
use warnings;
use namespace::autoclean;

use Image::Magick;
use List::AllUtils qw( min );
use Path::Class ();
use R2::Schema::File;
use R2::Types qw( FileIsImage PosInt Int );

use Moose;
use MooseX::StrictConstructor;
use MooseX::Params::Validate qw( validated_list );
use Moose::Util::TypeConstraints;

has 'file' => (
    is       => 'ro',
    isa      => FileIsImage,
    required => 1,
    handles  => [ 'path', 'uri' ],
);

class_type('Image::Magick');

has '_magick' => (
    is       => 'ro',
    isa      => 'Image::Magick',
    lazy     => 1,
    init_arg => undef,
    builder  => '_build_magick',
);

has 'height' => (
    is       => 'ro',
    isa      => PosInt,
    lazy     => 1,
    default  => sub { $_[0]->_magick()->get('height') },
    init_arg => undef,
);

has 'width' => (
    is       => 'ro',
    isa      => PosInt,
    lazy     => 1,
    default  => sub { $_[0]->_magick()->get('width') },
    init_arg => undef,
);

sub resize {
    my $self = shift;
    my ( $height, $width ) = validated_list(
        \@_,
        height => { isa => Int },
        width  => { isa => Int },
    );

    ( $height, $width ) = $self->_new_dimensions( $height, $width );

    my $dimensions  = $width . q{x} . $height;
    my $unique_name = $self->file()->file_id() . q{-} . $dimensions;

    my $file = eval { R2::Schema::File->new( unique_name => $unique_name ) };

    return R2::Image->new( file => $file )
        if $file;

    $file = $self->_make_resized_image( $height, $width, $dimensions,
        $unique_name );
}

sub _new_dimensions {
    my $self   = shift;
    my $height = shift;
    my $width  = shift;

    my $orig_height = $self->height();
    my $orig_width  = $self->width();

    return ( $orig_height, $orig_width )
        if $height >= $orig_height && $width >= $orig_width;

    my $height_r = $height / $orig_height;
    my $width_r  = $width / $orig_width;

    my $ratio = min( $height_r, $width_r );

    return (
        int( $orig_height * $ratio ),
        int( $orig_width * $ratio ),
    );
}

sub _make_resized_image {
    my $self        = shift;
    my $height      = shift;
    my $width       = shift;
    my $dimensions  = shift;
    my $unique_name = shift;

    my $resized_file
        = $self->file()->path()->dir()
        ->file( $self->file()->extensionless_basename() . q{-}
            . $dimensions . q{.}
            . $self->file()->extension() );

    my $orig = $self->_magick();
    my $new  = $orig->Clone();

    $new->Scale(
        height => $height,
        width  => $width,
    );

    $new->write(
        filename => $resized_file->stringify(),
        quality  => $orig->get('quality'),
        type     => 'Palette',
    );

    my $file = R2::Schema::File->insert(
        filename    => $resized_file->basename(),
        contents    => scalar $resized_file->slurp(),
        mime_type   => $self->file()->mime_type(),
        account_id  => $self->file()->account_id(),
        unique_name => $unique_name,
    );

    return ( ref $self )->new( file => $file );
}

sub _build_magick {
    my $self = shift;

    my $img = Image::Magick->new();
    $img->read( filename => $self->path() );

    return $img;
}

__PACKAGE__->meta()->make_immutable();

1;
