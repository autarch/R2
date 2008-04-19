package R2::Schema::File;

use strict;
use warnings;

use Digest::SHA qw( sha512_hex );
use MIME::Types;
use Path::Class qw( dir file );

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    my $file_t = $schema->table('File');

    has_table $file_t;

    has 'path' =>
        ( is      => 'ro',
          isa     => 'Path::Class::File',
          lazy    => 1,
          builder => '_build_path',
        );

    has '_cache_dir' =>
        ( is      => 'ro',
          isa     => 'Path::Class::Dir',
          lazy    => 1,
          builder => '_build_cache_dir',
        );

    has 'is_image' =>
        ( is      => 'ro',
          isa     => 'Bool',
          lazy    => 1,
          builder => '_build_is_image',
        );

    my $types = MIME::Types->new();
    transform 'mime_type' =>
        inflate { $types->type( $_[1] ) },
        deflate { ref $_[0] ? $_[0]->type() : $_[0] };
}


sub _build_path
{
    my $self = shift;

    my $path = file( $self->_cache_dir(), $self->file_name() );

    return $path
        if -f $path;

    $path->dir()->mkpath( 0, 0755 );

    open my $fh, '>', $path
        or die "Cannot write to $path: $!";

    print {$fh} $self->file_contents()
        or die "Cannot write to $path: $!";

    close $fh
        or die "Cannot write to $path: $!";

    return $path;
}

sub _build_cache_dir
{
    my $self = shift;

    my $config = R2::Config->new();

    my $hashed = sha512_hex( $self->file_id(), $config->secret() );

    return dir( $config->cache_dir(), 'files',
                substr( $hashed, 0, 2 ), $hashed );
}

{
    my %ImageType = map { $_ => 1 } qw( image/gif image/jpeg image/png );

    sub _build_is_image
    {
        my $self = shift;

        my $type = $self->mime_type();

        return $ImageType{ $type->type() };
    }
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;
