package R2::Config;

use strict;
use warnings;
use namespace::autoclean;
use autodie qw( :all );

use File::HomeDir;
use File::Spec;
use File::Temp qw( tempdir );
use Path::Class;
use R2::Types qw( Bool Str Int HashRef Dir File );
use R2::Util qw( string_is_empty );

use Moose;
use MooseX::Configuration;
use MooseX::Params::Validate qw( validated_list );

has is_production => (
    is      => 'rw',
    isa     => Bool,
    default => 0,
    section => 'R2',
    key     => 'is_production',
    documentation =>
        'A flag indicating whether or not this is a production install. This should probably be true unless you are actively developing R2.',
    writer => '_set_is_production',
);

has max_upload_size => (
    is      => 'ro',
    isa     => Int,
    default => ( 10 * 1024 * 1024 ),
    section => 'R2',
    key     => 'max_upload_size',
    documentation =>
        'The maximum size of an upload in bytes.',
);

has path_prefix => (
    is      => 'ro',
    isa     => Str,
    default => q{},
    section => 'R2',
    key     => 'path_prefix',
    documentation =>
        'The URI path prefix for your R2 install. By default, this is empty. This affects URI generation and resolution.',
    writer => '_set_path_prefix',
);

has serve_static_files => (
    is      => 'ro',
    isa     => Bool,
    builder => '_build_serve_static_files',
    section => 'R2',
    key     => 'static',
    documentation =>
        'If this is true, the R2 application will serve static files itself. Defaults to false when is_production is true.',
);

has secret => (
    is      => 'ro',
    isa     => Str,
    builder => '_build_secret',
    section => 'R2',
    key     => 'secret',
    documentation =>
        'A secret used as salt for digests in some URIs and for user authentication cookies. Changing this will invalidate all existing cookies.',
);

has mod_rewrite_hack => (
    is      => 'ro',
    isa     => Bool,
    default => q{},
    section => 'R2',
    key     => 'mod_rewrite_hack',
    documentation =>
        'The Apache mod_rewrite module does not pass the original path to the app server. Turn on this hack to work around that.',
);

has is_profiling => (
    is      => 'rw',
    isa     => Bool,
    lazy    => 1,
    builder => '_build_is_profiling',
    writer  => '_set_is_profiling',
);

has database_connection => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_database_connection',
);

has database_name => (
    is      => 'ro',
    isa     => Str,
    default => 'R2',
    section => 'database',
    key     => 'name',
    documentation =>
        'The name of the database.',
    writer => '_set_database_name',
);

has database_username => (
    is      => 'ro',
    isa     => Str,
    default => q{},
    section => 'database',
    key     => 'username',
    documentation =>
        'The username to use when connecting to the database. By default, this is empty.',
    writer => '_set_database_username',
);

has database_password => (
    is      => 'ro',
    isa     => Str,
    default => q{},
    section => 'database',
    key     => 'password',
    documentation =>
        'The password to use when connecting to the database. By default, this is empty.',
    writer => '_set_database_password',
);

has database_host => (
    is      => 'ro',
    isa     => Str,
    default => q{},
    section => 'database',
    key     => 'host',
    documentation =>
        'The host to use when connecting to the database. By default, this is empty.',
    writer => '_set_database_host',
);

has database_port => (
    is      => 'ro',
    isa     => Str,
    default => q{},
    section => 'database',
    key     => 'port',
    documentation =>
        'The port to use when connecting to the database. By default, this is empty.',
    writer => '_set_database_port',
);

has share_dir => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    builder => '_build_share_dir',
    section => 'dirs',
    key     => 'share',
    documentation =>
        'The directory where share files are located. By default, these are installed in the Perl module directory tree, but you might want to change this to something like /usr/local/share/R2.',
);

has cache_dir => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    builder => '_build_cache_dir',
    section => 'dirs',
    key     => 'cache',
    documentation =>
        'The directory where generated files are stored. Defaults to /var/cache/r2.',
);

has var_lib_dir => (
    is      => 'ro',
    isa     => Dir,
    coerce  => 1,
    builder => '_build_var_lib_dir',
    section => 'dirs',
    key     => 'var_lib',
    documentation =>
        'This directory stores files generated at install time (CSS and Javascript). Defaults to /var/lib/r2.',
);

has _home_dir => (
    is      => 'rw',
    isa     => Dir,
    lazy    => 1,
    default => sub { dir( File::HomeDir->my_home() ) },
    writer  => '_set_home_dir',
);

has etc_dir => (
    is      => 'rw',
    isa     => Dir,
    coerce  => 1,
    lazy    => 1,
    builder => '_build_etc_dir',
    writer  => '_set_etc_dir',
);

has files_dir => (
    is      => 'ro',
    isa     => Dir,
    lazy    => 1,
    builder => '_build_files_dir',
);

has temp_dir => (
    is      => 'ro',
    isa     => Dir,
    lazy    => 1,
    default => '_build_temp_dir',
);

has aim_key => (
    is            => 'ro',
    isa           => Str,
    default       => {},
    section       => 'messaging',
    key           => 'aim_key',
    documentation => 'The AIM key to use for retrieving AIM IM status.',
    writer        => '_set_aim_key',
);

{
    my $Instance;

    sub instance {
        return $Instance ||= shift->new(@_);
    }

    sub _clear_instance {
        undef $Instance;
    }
}

sub BUILD {
    my $self = shift;

    return unless $self->is_production();

    die
        'You must supply a value for [R2] - secret when running R2 in production'
        if string_is_empty( $self->secret() );
}

sub _build_config_file {
    my $self = shift;

    if ( !string_is_empty( $ENV{R2_CONFIG} ) ) {
        die
            "Nonexistent config file in R2_CONFIG env var: $ENV{R2_CONFIG}"
            unless -f $ENV{R2_CONFIG};

        return file( $ENV{R2_CONFIG} );
    }

    return if $ENV{R2_CONFIG_TESTING};

    my @dirs = dir('/etc/r2');
    push @dirs, $self->_home_dir()->subdir( '.r2', 'etc' )
        if $> && $self->_home_dir();

    for my $dir (@dirs) {
        my $file = $dir->file('r2.conf');

        return $file if -f $file;
    }

    return;
}

sub _build_serve_static_files {
    my $self = shift;

    return !( $ENV{MOD_PERL}
        || $self->is_production()
        || $self->is_profiling() );
}

{
    my @Profilers = qw(
        Devel/DProf.pm
        Devel/FastProf.pm
        Devel/NYTProf.pm
        Devel/Profile.pm
        Devel/Profiler.pm
        Devel/SmallProf.pm
    );

    sub _build_is_profiling {
        return 1 if grep { $INC{$_} } @Profilers;
        return 0;
    }
}

sub _build_var_lib_dir {
    my $self = shift;

    return $self->_dir(
        [ 'var', 'lib' ],
        '/var/lib/r2',
    );
}

sub _build_share_dir {
    my $self = shift;

    # I'd like to use File::ShareDir, but it blows up if the directory doesn't
    # exist, which isn't very fucking helpful. This is equivalent to
    # dist_dir('R2')
    my $share_dir = dir(
        dir( $INC{'R2/Config.pm'} )->parent(),
        'auto', 'share', 'dist',
        'R2'
    )->absolute()->cleanup();

    return $self->_dir(
        ['share'],
        $share_dir,
        dir('share')->absolute(),
    );
}

sub _build_cache_dir {
    my $self = shift;

    return $self->_dir(
        ['cache'],
        '/var/cache/r2',
    );
}

sub _build_etc_dir {
    my $self = shift;

    return $self->_pick_dir(
        ['etc'],
        '/etc/r2',
    );
}

sub _build_files_dir {
    my $self = shift;

    return $self->_cache_subdir('files');
}

sub _build_temp_dir {
    my $self = shift;

    my $temp = dir( File::Spec->tmpdir() )->subdir('r2');

    $self->_ensure_dir($temp);

    return $temp;
}

sub _cache_subdir {
    my $self = shift;
    my $name = shift;

    my $subdir = $self->cache_dir()->subdir($name);

    $self->_ensure_dir($subdir);

    return $subdir;
}

sub _dir {
    my $self = shift;

    my $dir = $self->_pick_dir(@_);

    $self->_ensure_dir($dir);

    return $dir;
}

my $TestingRootDir;

sub _pick_dir {
    my $self         = shift;
    my $pieces       = shift;
    my $prod_default = shift;
    my $dev_default  = shift;

    return dir($prod_default)
        if $self->is_production();

    return $dev_default
        if defined $dev_default;

    if ( $ENV{HARNESS_ACTIVE} ) {
        $TestingRootDir ||= tempdir( CLEANUP => 1 );

        return dir( $TestingRootDir, @{$pieces} );
    }

    return dir( $self->_home_dir(), '.r2', @{$pieces} );
}

sub _ensure_dir {
    my $self = shift;
    my $dir  = shift;

    return if -d $dir;

    $dir->mkpath( 0, 0750 )
        or die "Cannot make $dir: $!";

    return;
}

sub _build_database_connection {
    my $self = shift;

    my $dsn = 'dbi:Pg:dbname=' . $self->database_name();

    if ( my $host = $self->database_host() ) {
        $dsn .= ';host=' . $host;
    }

    if ( my $port = $self->database_port() ) {
        $dsn .= ';port=' . $port;
    }

    return {
        dsn      => $dsn,
        username => $self->database_username(),
        password => $self->database_password(),
    };
}

sub _build_secret {
    my $self = shift;

    return $self->is_production()
        ? q{}    # will cause an error in BUILD
        : 'a big secret';
}

around write_config_file => sub {
    my $orig = shift;
    my $self = shift;

    my $version = $R2::Config::VERSION || '(working copy)';
    my $generated = "Config file generated by R2 version $version";

    $self->$orig( generated_by => $generated, @_ );
};

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Configuration information for R2
