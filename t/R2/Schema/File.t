use strict;
use warnings;

use Test::More;

use lib 't/lib';

use R2::Test::RealSchema;

use Digest::SHA qw( sha512_hex );
use File::Slurp qw( read_file );
use List::AllUtils qw( first );
use R2::Schema::Account;
use R2::Schema::File;

my $account = R2::Schema::Account->new( name => q{Judean People's Front} );

{
    my $data = 'some text';

    my $file = R2::Schema::File->insert(
        mime_type  => 'text/plain',
        filename   => 'foo.txt',
        contents   => $data,
        account_id => $account->account_id(),
    );

    my $sha
        = sha512_hex( $file->file_id(), R2::Config->instance()->secret() );
    my $sha_dir = substr( $sha, 0, 2 );

    like(
        $file->path(),
        qr{\Qfiles/$sha_dir/$sha/foo.txt\E$},
        'path has expected end'
    );

    is(
        $file->extensionless_basename(), 'foo',
        'extensionless_basename is foo'
    );

    is(
        $file->extension(), 'txt',
        'extension is txt'
    );

    ok(
        -e $file->path(),
        'calling path() has side effect of writing the file to disk'
    );

    is(
        $file->uri(),
        qq{/files/$sha_dir/$sha/foo.txt},
        'uri has expected value'
    );

    is(
        scalar read_file( $file->path()->stringify() ), $data,
        'file contents on disk are identical to those passed to constructor'
    );

    ok( !$file->is_image(), 'file is not an image' );

    is(
        $file->unique_name(), $file->file_id(),
        'unique_name defaults to file_id'
    );

    $file->delete();

    ok(
        !-e $file->_cache_dir()->file( $file->filename() ),
        'file deletes itself off the disk when delete is called'
    );
}

{
    my $file = R2::Schema::File->insert(
        mime_type  => 'image/jpeg',
        filename   => '8th.jpg',
        contents   => '12345',
        account_id => $account->account_id(),
    );

    ok( $file->is_image(), 'file is an image' );
}

{
    for my $type (qw( text/plain image/tiff )) {
        ok(
            !R2::Schema::File->TypeIsImage($type),
            "$type is not an image type"
        );
    }

    for my $type (qw( image/gif image/jpeg image/png )) {
        ok(
            R2::Schema::File->TypeIsImage($type),
            "$type is an image type"
        );
    }
}

done_testing();
