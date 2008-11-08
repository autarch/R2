use strict;
use warnings;

use Test::More tests => 17;

use lib 't/lib';
use R2::Test qw( mock_schema mock_dbh );

use File::Slurp qw( read_file );
use List::Util qw( first );

use R2::Test::Config;
use R2::Config;
use R2::Schema::File;


my $mock = mock_schema();
my $dbh = mock_dbh();

{
    my $data = 'some text';

    $dbh->{mock_clear_history} = 1;

    # For insert
    $dbh->{mock_add_resultset} =
        [];

    $dbh->{mock_add_resultset} =
        [ [ qw( account_id contents filename mime_type unique_name ) ],
          [ 1, $data, 'foo.txt', 'text/plain', undef ],
        ];

    my $file = R2::Schema::File->insert( file_id   => 1,
                                         mime_type => 'text/plain',
                                         filename  => 'foo.txt',
                                         contents  => $data,
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

    is( $file->unique_name(), '1', 'unique_name defaults to file_id' );

    my $update = first { $_->is_update() } $mock->recorder()->actions_for_class('R2::Schema::File');
    is_deeply( $update->values(),
               { unique_name => '1' },
               'inserting a file will also update the unique_name to the value of the file_id if needed' );
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
    $mock->seed_class( 'R2::Schema::File' =>
                       { file_id => 2,
                         filename => 'test2.txt',
                         unique_name => '2',
                       },
                     );

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


