package R2::Role::Web::Form::ContactImage;

use Moose::Role;
use Chloro;

use R2::Schema::File;

field image => (
    isa       => 'Catalyst::Request::Upload',
    validator => '_validate_image',
);

sub _validate_image {
    my $self = shift;
    my $image  = shift;

    return if R2::Schema::File->TypeIsImage( $image->type() );

    return 'The image you provided is not a GIF, JPG, or PNG file.',
}

1;
