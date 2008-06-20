use strict;
use warnings;

use Test::More tests => 4;

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
    my $file = R2::Schema::File->new( file_id     => 1,
                                      mime_type   => 'text/plain',
                                      filename    => 'foo.txt',
                                      contents    => 'some text',
                                      _from_query => 1,
                                    );

    eval { R2::Image->new( file => $file ) };
    like( $@, qr/This file is not an image/,
          'cannot create an R2::Image with a non-image R2::Schema::File' );
}

{
    my $image_data = read_file( 't/files/shoe.jpg' );

    my $file = R2::Schema::File->new( file_id     => 1,
                                      mime_type   => 'image/jpeg',
                                      filename    => 'shoe.jpg',
                                      contents    => $image_data,
                                      _from_query => 1,
                                    );

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_insert_id} = 2;

    $dbh->{mock_add_resultset} =
        [ [ qw( file_id filename unique_name ) ],
        ];

    my $resized_data = read_file( 't/files/shoe-100x100.jpg' );

    $dbh->{mock_add_resultset} =
        [ [ qw( file_id filename account_id mime_type unique_name contents ) ],
          [ 2, 'shoe-100x100.jpg', 1, 'image/jpeg', '1-100x100', $resized_data ],
        ];

    my $image = R2::Image->new( file => $file );
    my $resized = $image->resize( height => 100, width => 100 );

    is( $resized->file()->filename(), 'shoe-100x100.jpg',
        'resized file has expected filename' );

    is( $resized->file()->unique_name(), '1-100x100',
        'resized file has expected unique_name' );

    is( Digest::SHA->new()->addfile( $resized->path()->stringify() )->b64digest(),
        'qyiMDI4bKHAezS/IGxneuUuOfp4',
        'file contents hash to expected digest value' );
}
