package R2::Schema::File;

use strict;
use warnings;

use Digest::SHA qw( sha512_hex );
use File::LibMagic ();
use File::Slurp qw( read_file );
use Path::Class qw( dir file );
use R2::Schema;
use R2::Util qw( string_is_empty );

use Fey::ORM::Table;
use MooseX::ClassAttribute;


{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    my $file_t = $schema->table('File');

    has_table $file_t;

    has 'path' =>
        ( is       => 'ro',
          isa      => 'Path::Class::File',
          lazy     => 1,
          builder  => '_build_path',
          init_arg => undef,
        );

    has extensionless_basename =>
        ( is       => 'ro',
          isa      => 'Str',
          lazy     => 1,
          builder  => '_build_extensionless_basename',
          init_arg => undef,
        );

    has 'extension' =>
        ( is       => 'ro',
          isa      => 'Str',
          lazy     => 1,
          builder  => '_build_extension',
          init_arg => undef,
        );

    has 'uri' =>
        ( is       => 'ro',
          isa      => 'Str',
          lazy     => 1,
          builder  => '_build_uri',
          init_arg => undef,
        );

    has '_cache_dir' =>
        ( is       => 'ro',
          isa      => 'Path::Class::Dir',
          lazy     => 1,
          builder  => '_build_cache_dir',
          init_arg => undef,
        );

    has 'is_image' =>
        ( is       => 'ro',
          isa      => 'Bool',
          lazy     => 1,
          builder  => '_build_is_image',
          init_arg => undef,
        );
}


around 'insert' => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    my $file = $class->$orig(%p);

    return $file if defined $file->unique_name();

    $file->update( unique_name => $file->file_id() );

    return $file;
};

sub _build_path
{
    my $self = shift;

    my $path = file( $self->_cache_dir(), $self->filename() );

    return $path
        if -f $path;

    $path->dir()->mkpath( 0, 0755 );

    open my $fh, '>', $path
        or die "Cannot write to $path: $!";

    print {$fh} $self->contents()
        or die "Cannot write to $path: $!";

    close $fh
        or die "Cannot write to $path: $!";

    return $path;
}

sub _build_extensionless_basename
{
    my $self = shift;

    my $path = $self->path();

    my $ext = $self->extension();

    my $basename = $self->path()->basename();

    $basename =~ s/\.\Q$ext\E$//;

    return $basename;
}

sub _build_extension
{
    my $self = shift;

    my $path = $self->path();

    my ($ext) = $path->basename() =~ /\.([^\.]+)$/;

    return defined $ext ? $ext : '';
}

sub _build_uri
{
    my $self = shift;

    my $path = $self->path();

    my $cache_dir = R2::Config->new()->cache_dir();

    ( my $uri = $path->stringify() ) =~ s{^\Q$cache_dir}{};

    return $uri;
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

        return $ImageType{ $self->mime_type() };
    }

    sub TypeIsImage
    {
        my $class = shift;
        my $type  = shift;

        return $ImageType{$type};
    }
}

no Fey::ORM::Table;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;
