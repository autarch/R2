use strict;
use warnings;

use Test::Exception;
use Test::More;

use lib 't/lib';
use R2::Test::RealSchema;

use Digest::SHA;
use File::Slurp qw( read_file );
use Image::Size qw( imgsize );
use R2::Test::Config;
use R2::Config;
use R2::Image;
use R2::Schema::Account;
use R2::Schema::File;

my $domain  = R2::Schema::Domain->DefaultDomain();
my $account = R2::Schema::Account->insert(
    name      => 'Account',
    domain_id => $domain->domain_id(),
);

my $image_data = read_file('t/files/shoe.jpg');

{
    my $file = R2::Schema::File->insert(
        mime_type  => 'text/plain',
        filename   => 'foo.txt',
        contents   => 'some text',
        account_id => $account->account_id(),
    );

    throws_ok(
        sub { R2::Image->new( file => $file ) },
        qr/\QThis file (foo.txt) is not an image/,
        'cannot create an R2::Image with a non-image R2::Schema::File'
    );
}

my $shoe_file;

{
    my $file = R2::Schema::File->insert(
        mime_type  => 'image/jpeg',
        filename   => 'shoe.jpg',
        contents   => $image_data,
        account_id => $account->account_id(),
    );

    $shoe_file = $file;

    my $resized_data = read_file('t/files/shoe-100x100.jpg');

    my $image = R2::Image->new( file => $file );
    my $resized = $image->resize( height => 100, width => 100 );

    is(
        $resized->file()->filename(), 'shoe-100x100.jpg',
        'resized file has expected filename'
    );

    my $file_id = $file->file_id();

    is(
        $resized->file()->unique_name(), $file_id . '-100x100',
        'resized file has expected unique_name'
    );

    my ( $x, $y ) = imgsize( $resized->path()->stringify() );
    is( $x, 100, 'resized x is 100' );
    is( $y, 100, 'resized y is 100' );
}

{
    my $file = R2::Schema::File->new( file_id => $shoe_file->file_id() );

    my $resized_data = read_file('t/files/shoe-100x100.jpg');

    my $image = R2::Image->new( file => $file );
    my $resized = $image->resize( height => 100, width => 100 );

    is(
        $resized->file()->filename(), 'shoe-100x100.jpg',
        'resized file has expected filename'
    );

    my $file_id = $file->file_id();

    is(
        $resized->file()->unique_name(), $file_id . '-100x100',
        'resized file has expected unique_name'
    );

    is(
        Digest::SHA->new()->addfile( $resized->path()->stringify() )
            ->b64digest(),
        '+klHWVKxwpMaJ6WZ0Cu4t5RkRS0',
        'file contents hash to expected digest value'
    );
}

{
    my $file = R2::Schema::File->insert(
        mime_type  => 'image/jpeg',
        filename   => 'shoe.jpg',
        contents   => $image_data,
        account_id => $account->account_id(),
    );

    my $image = R2::Image->new( file => $file );

    is_deeply(
        [ $image->_new_dimensions( 200, 50 ) ],
        [ 50, 50 ],
        'asking for 200x50 gets 50x50'
    );

    is_deeply(
        [ $image->_new_dimensions( 50, 300 ) ],
        [ 50, 50 ],
        'asking for 50x300 gets 50x50'
    );

    is_deeply(
        [ $image->_new_dimensions( 300, 50 ) ],
        [ 50, 50 ],
        'asking for 300x50 gets 50x50'
    );

    is_deeply(
        [ $image->_new_dimensions( 350, 325 ) ],
        [ 250, 250 ],
        'asking for 350x325 gets 250x250'
    );

}

done_testing();
