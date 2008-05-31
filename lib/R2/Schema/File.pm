package R2::Schema::File;

use strict;
use warnings;

use Digest::SHA qw( sha512_hex );
use File::LibMagic ();
use File::Slurp qw( read_file );
use Path::Class qw( dir file );
use R2::Util qw( string_is_empty );

use MooseX::ClassAttribute;
use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    my $file_t = $schema->table('File');

    has_table $file_t;

    has 'path' =>
        ( is       => 'ro',
          isa      => 'Path::Class::File',
          lazy     => 1,
          builder  => '_build_path',
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

    class_has '_FileMagic' =>
        ( is      => 'ro',
          isa     => 'File::LibMagic',
          lazy    => 1,
          default => sub { File::LibMagic->new() },
        );

    class_has '_SelectByUniqueName' =>
        ( is      => 'ro',
          isa     => 'Fey::SQL::Select',
          lazy    => 1,
          default => \&_build_SelectByUniqueName,
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

sub _load_from_dbms
{
    my $self = shift;
    my $p    = shift;

    if ( ! string_is_empty( $p->{unique_name} ) )
    {
        return if $self->_load_by_unique_name( $p->{unique_name} );
    }

    return $self->SUPER::_load_from_dbms($p);
}

sub _load_by_unique_name
{
    my $self     = shift;
    my $filename = shift;

    my $select = $self->_SelectByUniqueName();

    my $dbh = $self->_dbh($select);

    my $rows = $dbh->selectall_arrayref( $select->sql($dbh), { Slice => {} }, $filename );

    return unless @{ $rows } == 1;

    $self->_set_column_values_from_hashref( $rows->[0] );

    return 1;
}

sub _build_SelectByUniqueName
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('File') )
           ->from( $schema->tables( 'File' ) )
           ->where( $schema->table('File')->column('unique_name'),
                    '=', Fey::Placeholder->new() );

    return $select;
}

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

        my $type = $self->mime_type();

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
no Moose;

__PACKAGE__->meta()->make_immutable();

1;
