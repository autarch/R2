use strict;
use warnings;

use Test::Exception;
use Test::More tests => 55;

use File::Slurp qw( write_file );
use File::Temp qw( tempdir );
use Path::Class;
use R2::Config;


my $config = R2::Config->new();
my $file = file( tempdir( CLEANUP => 1 ), 'r2.conf' );

{
    local $ENV{R2_CONFIG} = '/ this best not be a real / path';

    throws_ok( sub { $config->_build_config_file() },
               qr/nonexistent config file/i,
               'bad value for R2_CONFIG throws an error' );
}

{
    no warnings 'redefine';
    local *Path::Class::File::stringify = sub { '/ also should not / exist' };

    throws_ok( sub { $config->_build_config_file() },
               qr/cannot find a config file/i,
               'error is thrown when we no config file can be found' );
}

{
    $config->_set_config_hash( { dirs => { foo_bar => '/my/foo/bar' } } );

    is( $config->_dir( [ 'foo', 'bar' ], '/prod/default' ),
        '/my/foo/bar',
        '_dir() returns value from config as first choice' );

    $config->_set_is_production(1);
    $config->_set_config_hash( { } );

    is( $config->_dir( [ 'foo', 'bar' ], '/prod/default' ),
        '/prod/default',
        '_dir() returns prod default when is_production is true' );

    $config->_set_is_production(0);

    is( $config->_dir( [ 'foo', 'bar' ], '/prod/default', '/dev/default' ),
        '/dev/default',
        '_dir() returns dev default when is_production is true and dev default is provided' );

    $config->_set_home_dir( dir( '/my/home' ) );

    is( $config->_dir( [ 'foo', 'bar' ], '/prod/default' ),
        '/my/home/.r2/foo/bar',
        '_dir() returns dir under $HOME/.r2 as final fallback' );
}

{
    no warnings 'redefine';

    my %hash = ( R2 => { is_production => 1 } );
    local *Config::INI::Reader::read_file =
        sub { return { %hash } };
    throws_ok( sub { $config->_build_config_hash() },
               qr/^\QYou must supply a value for [R2] - secret when running R2 in production/,
               'in production the config file must set a value for the secret' );

    $hash{R2}{secret} = 'X';

    lives_ok( sub { $config->_build_config_hash() },
               'no error in production when config file has a value for the secret' );
}

{
    my %imports = map { $_ => 1 } @{ $config->_build_catalyst_imports() };
    ok( $imports{AuthenCookie}, 'AuthenCookie is always loaded' );
    ok( $imports{'+R2::Plugin::User'}, 'R2::Plugin::User is always loaded' );
    ok( $imports{'Static::Simple'}, 'Static::Simple is loaded when not under mod_perl or profiling' );
    ok( $imports{StackTrace}, 'Static::Simple is loaded when not in production or profiling' );
}

{
    local $ENV{MOD_PERL} = 1;
    my %imports = map { $_ => 1 } @{ $config->_build_catalyst_imports() };

    ok( $imports{AuthenCookie}, 'AuthenCookie is always loaded' );
    ok( $imports{'+R2::Plugin::User'}, 'R2::Plugin::User is always loaded' );
    ok( ! $imports{'Static::Simple'}, 'Static::Simple is not loaded under mod_perl' );
}

{
    $config->_set_is_profiling(1);
    my %imports = map { $_ => 1 } @{ $config->_build_catalyst_imports() };
    $config->_set_is_profiling(0);

    ok( $imports{AuthenCookie}, 'AuthenCookie is always loaded' );
    ok( $imports{'+R2::Plugin::User'}, 'R2::Plugin::User is always loaded' );
    ok( ! $imports{'Static::Simple'}, 'Static::Simple is not loaded when profiling' );
}

{
    $config->_set_is_production(1);
    my %imports = map { $_ => 1 } @{ $config->_build_catalyst_imports() };
    $config->_set_is_production(0);

    ok( $imports{AuthenCookie}, 'AuthenCookie is always loaded' );
    ok( $imports{'+R2::Plugin::User'}, 'R2::Plugin::User is always loaded' );
    ok( ! $imports{StackTrace}, 'StackTrace is not loaded when in production' );
}

{
    my $cat = $config->_build_catalyst_config();

    is( $cat->{default_view}, 'Mason',
        'check default_view Catalyst config' );

    ok( $cat->{static}, 'has static config when not in production' );
    is_deeply( $cat->{static}{dirs}, [ qw( files images js css static w3c ) ],
               'static dirs is expected list of dirs' );

    is( scalar @{ $cat->{'Log::Dispatch'} }, 1,
        'just one logger when not in production' );

    is( $cat->{'Log::Dispatch'}[0]{class}, 'Screen',
        'logger is Screen when not in production' );
}

{
    $config->_set_is_production(1);
    my $cat = $config->_build_catalyst_config();
    $config->_set_is_production(0);

    ok( ! $cat->{static}, 'does not have static config when in production' );

    is( scalar @{ $cat->{'Log::Dispatch'} }, 1,
        'just one logger when in production' );

    is( $cat->{'Log::Dispatch'}[0]{class}, 'Syslog',
        'logger is Syslog when in production' );

}

{
    no warnings 'once';
    local *Apache2::ServerUtil::server = sub { 1 };

    $config->_set_is_production(1);
    my $cat = do { local $ENV{MOD_PERL} = 1; $config->_build_catalyst_config(); };
    $config->_set_is_production(0);

    ok( ! $cat->{static}, 'does not have static config when in production' );

    is( scalar @{ $cat->{'Log::Dispatch'} }, 1,
        'just one logger when in production' );

    is( $cat->{'Log::Dispatch'}[0]{class}, 'ApacheLog',
        'logger is ApacheLog when in production under mod_perl' );

}

{
    ok( ! $config->_build_is_profiling(), 'is_profiling is normally false' );

    local $INC{'Devel/NYTProf.pm'} = 1;

    ok( $config->_build_is_profiling(), 'is_profiling is true when a profiler is loaded' );
}

{
    is( $config->_build_var_lib_dir(),
        dir( $config->_home_dir(), '.r2', 'var', 'lib' ),
        'by default var lib dir is under home dir'
      );

    is( $config->_build_share_dir(),
        dir( dir()->absolute(), 'share' ),
        'by default share dir is in checkout'
      );

    is( $config->_build_etc_dir(),
        dir( $config->_home_dir(), '.r2', 'etc' ),
        'by default etc dir is under home dir'
      );

    is( $config->_build_cache_dir(),
        dir( $config->_home_dir(), '.r2', 'cache' ),
        'by default cache dir is under home dir'
      );
}

{
    my $hash = $config->_config_hash();
    local $hash->{db} = {};

    my $dbi = $config->_build_dbi_config();
    is( $dbi->{dsn}, 'dbi:Pg:dbname=R2',
        'database name defaults to R2, ignores host and port if not set' );

    is( $dbi->{username}, q{},
        'database username defaults to empty string' );
    is( $dbi->{password}, q{},
        'database password defaults to empty string' );
}

{
    my $mason = $config->_build_mason_config();

    ok( ! ref $mason->{comp_root}, 'comp_root is a string, not an object' );
    ok( ! ref $mason->{data_dir}, 'data_dir is a string, not an object' );

    is( $mason->{comp_root},
        dir( $config->share_dir(), 'mason' ),
        'comp_root is under share dir' );
    is( $mason->{data_dir},
        dir( $config->cache_dir(), 'mason', 'web' ),
        'data_dir is under cache dir as mason/web' );

    ok( ! $mason->{static_source}, 'static source is false when not in production' );
}

{
    $config->_set_is_production(1);
    my $mason = $config->_build_mason_config();
    $config->_set_is_production(0);

    ok( $mason->{static_source}, 'static source is true when in production' );
    is( $mason->{static_source_touch_file},
        file( $config->etc_dir(), 'mason-touch' )->stringify(),
        'touch file is set and under etc dir when in production' );
}

{
    is( $config->_build_static_path_prefix(), undef,
        'static path prefix defaults to undef when not in production and there is no path prefix' );

    $config->_set_path_prefix('/foo/r2');
    is( $config->_build_static_path_prefix(), '/foo/r2',
        'static path prefix defaults to path prefix when not in production and path prefix is set' );

    $config->_set_is_production(1);

    no warnings 'redefine';
    local *R2::Config::read_file = sub { '2713' };
    is( $config->_build_static_path_prefix(), '/foo/r2/2713',
        'static path prefix includes revision and path prefix in production' );

    $config->_set_path_prefix(undef);

    is( $config->_build_static_path_prefix(), '/2713',
        'static path prefix is only revision in production when there is no path prefix' );

    $config->_set_is_production(0);
}

{
    is( $config->_build_secret(), 'a big secret',
        'secret is "a big secret" when not in production' );

    my $hash = $config->_config_hash();
    local $hash->{R2}{secret} = 'new secret';

    $config->_set_is_production(1);
    is( $config->_build_secret(), 'new secret',
        'secret is read from config hash when in production' );
    $config->_set_is_production(0);
}

{
    write_file( $file->stringify(), <<'EOF' );
[db]
name = Foo
username = Bar
password = baz
host = example.com
port = 42
EOF

    local $ENV{R2_CONFIG} = $file->stringify();

    $config->_clear_config_file();
    $config->_clear_config_hash();

    is_deeply( $config->dbi_config(),
               { dsn      => 'dbi:Pg:dbname=Foo;host=example.com;port=42',
                 username => 'Bar',
                 password => 'baz',
               },
               'dbi_config() from config file'
             );
}
