use strict;
use warnings;

use Test::More tests => 16;

use lib 't/lib';
use R2::Test qw( mock_dbh );

use File::Slurp qw( read_file );

use R2::Test::Config;
use R2::Config;
use R2::Schema::File;


my $dbh = mock_dbh();

{
    my $data = 'some text';
    my $file = R2::Schema::File->new( file_id     => 1,
                                      mime_type   => 'text/plain',
                                      filename    => 'foo.txt',
                                      contents    => $data,
                                      _from_query => 1,
                                    );

    like( $file->path(),
        qr{\Qfiles/f0/f0075278acf7e8dc8d64ae8a801626c92c487cb831d21e1798bf344956d7c81d1ed6d5dc7f4d713b84dd29c52213da26d5f9ca6d5aa67379a9d5bba0b0b3a2ff/foo.txt\E$},
        'path has expected end' );

    is( $file->extensionless_basename(), 'foo',
        'extensionless_basename is foo' );

    is( $file->extension(), 'txt',
        'extension is txt' );

    ok( -e $file->path(),
        'calling path() has side effect of writing the file to disk' );

    is( $file->uri(),
        q{/files/f0/f0075278acf7e8dc8d64ae8a801626c92c487cb831d21e1798bf344956d7c81d1ed6d5dc7f4d713b84dd29c52213da26d5f9ca6d5aa67379a9d5bba0b0b3a2ff/foo.txt},
        'uri has expected value' );

    is( scalar read_file( $file->path()->stringify() ), $data,
        'file contents on disk are identical to those passed to constructor' );

    ok( ! $file->is_image(), 'file is not an image' );

    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} =
        [ [ qw( file_id filename unique_name ) ],
          [ 1, 'foo.txt', '1' ],
        ];

    is( $file->unique_name(), '1', 'unique_name defaults to file_id' );
}

{
    my $file = R2::Schema::File->new( file_id     => 1,
                                      mime_type   => 'image/jpeg',
                                      filename    => '8th.jpg',
                                      contents    => '12345',
                                      _from_query => 1,
                                    );

    ok( $file->is_image(), 'file is an image' );
}

{
    $dbh->{mock_clear_history} = 1;

    $dbh->{mock_add_resultset} =
        [ [ qw( file_id filename unique_name ) ],
          [ 2, 'test2.txt', '2' ],
        ];

    my $file = R2::Schema::File->new( unique_name => '2' );
    ok( $file, 'loaded file by unique_name' );
    is( $file->file_id(), 2, 'file_id is expected value' );
}

{
    for my $type ( qw( text/plain image/tiff ) )
    {
        ok( ! R2::Schema::File->TypeIsImage($type),
            "$type is not an image type" );
    }

    for my $type ( qw( image/gif image/jpeg image/png ) )
    {
        ok( R2::Schema::File->TypeIsImage($type),
            "$type is an image type" );
    }
}


