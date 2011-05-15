use strict;
use warnings;

use Test::Most;

use autodie;
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use File::Slurp qw( read_file );
use File::Temp qw( tempdir );
use Path::Class qw( dir file );
use R2::Config;

my $dir = tempdir( CLEANUP => 1 );

$ENV{HARNESS_ACTIVE}    = 0;
$ENV{R2_CONFIG_TESTING} = 1;

{
    my $config = R2::Config->new();

    is_deeply(
        $config->_raw_config(),
        {},
        'config hash is empty by default'
    );
}

{
    my $config = R2::Config->new();

    is(
        $config->secret, 'a big secret',
        'secret has a basic default in dev environment'
    );
}

{
    local $ENV{R2_CONFIG} = '/path/to/nonexistent/file.conf';

    throws_ok(
        sub { R2::Config->new() },
        qr/\QNonexistent config file in R2_CONFIG env var/,
        'R2_CONFIG pointing to bad file throws an error'
    );
}

{
    my $dir = tempdir( CLEANUP => 1 );
    my $file = "$dir/r2.conf";
    open my $fh, '>', $file;
    print {$fh} <<'EOF';
[R2]
secret = foobar
EOF
    close $fh;

    {
        local $ENV{R2_CONFIG} = $file;

        my $config = R2::Config->new();

        is_deeply(
            $config->_raw_config(), {
                R2 => { secret => 'foobar' },
            },
            'config hash uses data from file in R2_CONFIG'
        );
    }

    open $fh, '>', $file;
    print {$fh} <<'EOF';
[R2]
is_production = 1
EOF
    close $fh;

    {
        local $ENV{R2_CONFIG} = $file;

        throws_ok(
            sub { R2::Config->new() },
            qr/\QYou must supply a value for [R2] - secret when running R2 in production/,
            'If is_production is true in config, there must be a secret defined'
        );
    }

    open $fh, '>', $file;
    print {$fh} <<'EOF';
[R2]
is_production = 1
secret = foobar
EOF
    close $fh;

    {
        local $ENV{R2_CONFIG} = $file;

        my $config = R2::Config->new();

        is_deeply(
            $config->_raw_config(), {
                R2 => {
                    secret        => 'foobar',
                    is_production => 1,
                },
            },
            'config hash with is_production true and a secret defined'
        );
    }
}

{
    my $config = R2::Config->new();

    ok( $config->serve_static_files(), 'by default we serve static files' );

    $config = R2::Config->new();

    $config->_set_is_production(1);

    ok(
        !$config->serve_static_files(),
        'does not serve static files in production'
    );

    $config = R2::Config->new();

    $config->_set_is_production(0);

    $config->_set_is_profiling(1);

    ok(
        !$config->serve_static_files(),
        'does not serve static files when profiling'
    );

    $config = R2::Config->new();

    $config->_set_is_profiling(0);

    {
        local $ENV{MOD_PERL} = 1;

        ok(
            !$config->serve_static_files(),
            'does not serve static files under mod_perl'
        );
    }
}

{
    my $config = R2::Config->new();

    is(
        $config->is_profiling(), 0,
        'is_profiling defaults to false'
    );
}

{
    local $INC{'Devel/NYTProf.pm'} = 1;

    my $config = R2::Config->new();

    is(
        $config->is_profiling(), 1,
        'is_profiling defaults is true if Devel::NYTProf is loaded'
    );
}

{
    my $config = R2::Config->new();

    my $checkout = file($0)->absolute()->dir()->parent()->parent();

    is(
        $config->var_lib_dir(),
        $checkout->subdir( '.r2', 'var', 'lib' ),
        'var lib dir defaults to $CHECKOUT/.r2/var/lib'
    );

    is(
        $config->share_dir(),
        dir( dirname( abs_path($0) ), '..', '..', 'share' )->resolve(),
        'share dir defaults to $CHECKOUT/share'
    );

    is(
        $config->etc_dir(),
        $checkout->subdir( '.r2', 'etc' ),
        'etc dir defaults to $CHECKOUT/.r2/etc'
    );

    is(
        $config->cache_dir(),
        $checkout->subdir( '.r2', 'cache' ),
        'cache dir defaults to $CHECKOUT/.r2/cache'
    );

    is(
        $config->files_dir(),
        $checkout->subdir( '.r2', 'cache', 'files' ),
        'files dir defaults to $CHECKOUT/.r2/cache/files'
    );
}

{
    my $config = R2::Config->new();

    $config->_set_is_production(1);

    no warnings 'redefine';
    local *R2::Config::_ensure_dir = sub {return};

    is(
        $config->var_lib_dir(),
        '/var/lib/r2',
        'var lib dir defaults to /var/lib/r2 in production'
    );

    my $share_dir = dir(
        dir( $INC{'R2/Config.pm'} )->parent(),
        'auto', 'share', 'dist',
        'R2'
    )->absolute()->cleanup();

    is(
        $config->share_dir(),
        $share_dir,
        'share dir defaults to /usr/local/share/r2 in production'
    );

    is(
        $config->etc_dir(),
        '/etc/r2',
        'etc dir defaults to /etc/r2 in production'
    );

    is(
        $config->cache_dir(),
        '/var/cache/r2',
        'cache dir defaults to /var/cache/r2 in production'
    );

    is(
        $config->files_dir(),
        '/var/cache/r2/files',
        'files dir defaults to /var/cache/r2/files in production'
    );
}

{
    my $dir = tempdir( CLEANUP => 1 );
    my $file = "$dir/r2.conf";
    open my $fh, '>', $file;
    print {$fh} <<'EOF';
[dirs]
var_lib = /foo/var/lib
share   = /foo/share
cache   = /foo/cache
EOF
    close $fh;

    no warnings 'redefine';
    local *R2::Config::_ensure_dir = sub {return};

    {
        local $ENV{R2_CONFIG} = $file;

        my $config = R2::Config->new();

        is(
            $config->var_lib_dir(),
            dir('/foo/var/lib'),
            'var lib dir defaults gets /foo/var/lib from file'
        );

        is(
            $config->share_dir(),
            dir('/foo/share'),
            'share dir defaults gets /foo/share from file'
        );

        is(
            $config->cache_dir(),
            dir('/foo/cache'),
            'cache dir defaults gets /foo/cache from file'
        );
    }
}

{
    my $config = R2::Config->new();

    is_deeply(
        $config->database_connection(), {
            dsn      => 'dbi:Pg:dbname=R2',
            username => q{},
            password => q{},
        },
        'default database config'
    );
}

{
    my $dir = tempdir( CLEANUP => 1 );
    my $file = "$dir/r2.conf";
    open my $fh, '>', $file;
    print {$fh} <<'EOF';
[database]
name = Foo
host = example.com
port = 9876
username = user
password = pass
EOF
    close $fh;

    local $ENV{R2_CONFIG} = $file;

    my $config = R2::Config->new();

    is_deeply(
        $config->database_connection(), {
            dsn      => 'dbi:Pg:dbname=Foo;host=example.com;port=9876',
            username => 'user',
            password => 'pass',
        },
        'database config from file'
    );
}

{
    my $config = R2::Config->new();

    my $dir = tempdir( CLEANUP => 1 );

    my $new_dir = dir($dir)->subdir('foo');

    $config->_ensure_dir($new_dir);

    ok( -d $new_dir, '_ensure_dir makes a new directory if needed' );
}

{
    my $dir = tempdir( CLEANUP => 1 );

    my $file = "$dir/r2.conf";

    my $config = R2::Config->new();

    $config->write_config_file(
        file   => $file,
        values => {
            'database_name'     => 'Foo',
            'database_username' => 'fooer',
            'share_dir'         => '/path/to/share',
            'antispam_key'      => 'abcdef',
        },
    );

    my $content = read_file($file);
    like(
        $content, qr/\Q; Config file generated by R2 version \E.+/,
        'generated config file includes R2 version'
    );

    like(
        $content, qr/\Q; static =/,
        'generated config file does not set static'
    );

    like(
        $content, qr/\Qname = Foo/,
        'generated config file includes explicit set value for database name'
    );

    like(
        $content, qr/\Qusername = fooer/,
        'generated config file includes explicit set value for database username'
    );

    like(
        $content, qr/\[database\].+?name = Foo.+?username = fooer/s,
        'generated config file keys are in order defined by meta description'
    );

    like(
        $content, qr/\[R2\].+?\[database\].+?\[messaging\]/s,
        'section order matches order of definition on R2::Config'
    );
}

done_testing();
