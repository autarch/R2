use strict;
use warnings;

use Test::More tests => 3;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use Digest::SHA;
use File::Slurp qw( read_file );
use R2::Test::Config;
use R2::Config;
use R2::Image;
use R2::Schema::File;


my $dbh = mock_dbh();

{
    my $file = R2::Schema::File->new( file_id       => 1,
                                      mime_type     => 'text/plain',
                                      file_name     => 'foo.txt',
                                      file_contents => 'some text',
                                      _from_query   => 1,
                                    );

    eval { R2::Image->new( file => $file ) };
    like( $@, qr/This file is not an image/,
          'cannot create an R2::Image with a non-image R2::Schema::File' );
}

{
    my $image_data = read_file( 't/files/8th.jpg' );

    my $file = R2::Schema::File->new( file_id       => 1,
                                      mime_type     => 'image/jpeg',
                                      file_name     => '8th.jpg',
                                      file_contents => $image_data,
                                      _from_query   => 1,
                                    );

    my $image = R2::Image->new( file => $file );
    my $resized_path = $image->resize( height => 100, width => 100 );

    is( $resized_path->basename(), '8th-100x100.jpg',
        'resized file has expected basename' );

    is( Digest::SHA->new()->addfile( $resized_path->stringify() )->b64digest(),
        'RNI++LwRNzNokhOz1LNbijnK/mc',
        'file contents hash to expected digest value' );
}
