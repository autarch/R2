use strict;
use warnings;

use Test::More tests => 5;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use File::Slurp qw( read_file );

use R2::Test::Config;
use R2::Config;
use R2::Schema::File;


my $dbh = mock_dbh();

{
    my $data = 'some text';
    my $file = R2::Schema::File->new( file_id       => 1,
                                      mime_type     => 'text/plain',
                                      file_name     => 'foo.txt',
                                      file_contents => $data,
                                      _from_query   => 1,
                                    );

    like( $file->path(),
        qr{\Qfiles/f0/f0075278acf7e8dc8d64ae8a801626c92c487cb831d21e1798bf344956d7c81d1ed6d5dc7f4d713b84dd29c52213da26d5f9ca6d5aa67379a9d5bba0b0b3a2ff/foo.txt\E$},
        'path has expected end' );

    ok( -e $file->path(),
        'calling path() has side effect of writing the file to disk' );

    is( scalar read_file( $file->path()->stringify() ), $data,
        'file contents on disk are identical to those passed to constructor' );

    ok( ! $file->is_image(), 'file is not an image' );

}

{
    my $file = R2::Schema::File->new( file_id       => 1,
                                      mime_type     => 'image/jpeg',
                                      file_name     => '8th.jpg',
                                      file_contents => '12345',
                                      _from_query   => 1,
                                    );

    ok( $file->is_image(), 'file is an image' );
}
