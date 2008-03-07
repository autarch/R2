package R2::Config;

use strict;
use warnings;

use Config::INI::Reader;
use File::HomeDir;
use Path::Class;
use R2::Util qw( string_is_empty );
use Sys::Hostname qw( hostname );

use MooseX::Singleton;

has 'is_production' =>
    ( is      => 'rw',
      isa     => 'Bool',
      lazy    => 1,
      default => sub { $_[0]->_config_hash()->{R2}{is_production} },
      # for testing
      writer  => '_set_is_production',
    );

has 'is_test' =>
    ( is      => 'rw',
      isa     => 'Bool',
      lazy    => 1,
      default => sub { $_[0]->_config_hash()->{R2}{is_test} },
      # for testing
      writer  => '_set_is_test',
    );

has '_is_profiling' =>
    ( is      => 'rw',
      isa     => 'Bool',
      lazy    => 1,
      builder => '_profiler_loaded',
      # for testing
      writer  => '_set_is_profiling',
    );

has '_config_hash' =>
    ( is      => 'rw',
      isa     => 'HashRef',
      lazy    => 1,
      builder => '_read_config_file',
      # for testing
      writer  => '_set_config_hash',
    );

has '_config_file' =>
    ( is      => 'ro',
      isa     => 'Path::Class::File',
      lazy    => 1,
      builder => '_find_config_file',
    );

has 'catalyst_imports' =>
    ( is      => 'ro',
      isa     => 'ArrayRef[ClassName]',
      lazy    => 1,
      builder => '_catalyst_imports',
    );

has '_home_dir' =>
    ( is      => 'ro',
      isa     => 'Path::Class::Dir',
      lazy    => 1,
      default => sub { dir( File::HomeDir->my_home() ) },
      writer  => '_set_home_dir',
    );

has 'var_lib_dir' =>
    ( is      => 'ro',
      isa     => 'Path::Class::Dir',
      lazy    => 1,
      builder => '_var_lib_dir',
    );

has 'share_dir' =>
    ( is      => 'ro',
      isa     => 'Path::Class::Dir',
      lazy    => 1,
      builder => '_share_dir',
    );

has 'etc_dir' =>
    ( is      => 'ro',
      isa     => 'Path::Class::Dir',
      lazy    => 1,
      builder => '_etc_dir',
    );

has 'cache_dir' =>
    ( is      => 'ro',
      isa     => 'Path::Class::Dir',
      lazy    => 1,
      builder => '_cache_dir',
    );

has 'static_path_prefix' =>
    ( is      => 'ro',
      isa     => 'Maybe[Str]',
      lazy    => 1,
      builder => '_static_path_prefix',
      # for testing
      writer  => '_set_static_path_prefix',
    );

has 'forgot_pw_secret' =>
    ( is      => 'ro',
      isa     => 'Str',
      lazy    => 1,
      builder => '_forgot_pw_secret',
    );

has 'authen_secret' =>
    ( is      => 'ro',
      isa     => 'Str',
      lazy    => 1,
      builder => '_authen_secret',
    );


sub _read_config_file
{
    my $self = shift;

    my $hash = Config::INI::Reader->read_file( $self->_config_file() );

    my $is_prod = $hash->{R2}{is_production};

    if ( $is_prod )
    {
        die "If is_production is true, you must supply a value for [secrets] - forgot_pw"
            if string_is_empty( $hash->{secrets}{forgot_pw} );

        die "If is_production is true, you must supply a value for [secrets] - authen"
            if string_is_empty( $hash->{secrets}{authen} );
    }

    return $hash;
}

sub _find_config_file
{
    my $self = shift;

    if ( ! string_is_empty( $ENV{R2_CONFIG} ) )
    {
        die "Nonexistent config file in R2_CONFIG env var: $ENV{R2_CONFIG}"
            unless -f $ENV{R2_CONFIG};

        return file( $ENV{R2_CONFIG} );
    }

    my @looked;
    for my $dir ( dir( '/etc/r2' ), $self->_home_dir()->subdir('.r2') )
    {
        my $file = $dir->file('r2.conf');

        return $file if -f $file;

        push @looked, $file;
    }

    die "Cannot find a config file anywhere I looked (@looked)\n";
}

{
#            +R2::Plugin::Session::Store::R2
    my @StandardImports =
        qw( AuthenCookie
            +R2::Plugin::ErrorHandling
            DR::Session
            DR::Session::State::URI
            Log::Dispatch
            RedirectAndDetach
            SubRequest
          );

    sub _catalyst_imports
    {
        my $self = shift;

        my @imports = @StandardImports;
        push @imports, 'Static::Simple'
            unless $ENV{MOD_PERL} || $self->_is_profiling();

        push @imports, 'StackTrace'
            unless $self->is_production() ||$self->_is_profiling();

        return \@imports;
    }
}

{
    my @Profilers =
        qw( Devel/DProf.pm
            Devel/FastProf.pm
            Devel/NYTProf.pm
            Devel/Profile.pm
            Devel/Profiler.pm
            Devel/SmallProf.pm
          );

    sub _profiler_loaded
    {
        return 1 if grep { $INC{$_} } @Profilers;
        return 0;
    }
}

sub _var_lib_dir
{
    my $self = shift;

    return $self->_dir( [ 'var', 'lib' ],
                        '/var/lib/r2',
                      );
}

sub _share_dir
{
    my $self = shift;

    return $self->_dir( [ 'share' ],
                        '/usr/local/share/r2',
                        dir( dir()->absolute(), 'share' ),
                      );
}

sub _etc_dir
{
    my $self = shift;

    return $self->_dir( [ 'cache' ],
                        '/etc/r2',
                      );
}

sub _cache_dir
{
    my $self = shift;

    return $self->_dir( [ 'cache' ],
                        '/var/cache/r2',
                      );
}

sub _dir
{
    my $self         = shift;
    my $pieces       = shift;
    my $prod_default = shift;
    my $dev_default  = shift;

    my $config = $self->_config_hash();

    my $key = join '_', @{ $pieces };

    return dir( $config->{dirs}{$key} )
        if exists $config->{dirs}{$key};

    return dir( $prod_default )
        if $self->is_production();

    return $dev_default
        if defined $dev_default;

    return dir( $self->_home_dir(), '.r2', @{ $pieces } );
}

sub _catalyst_config
{
    my $self = shift;

    my %config =
        ( default_view   => 'Mason',

          session        =>
          { expires        => ( 60 * 5 ),
            dbi_table      => 'Session',
            dbi_dbh        => 'R2::Plugin::Session::Store::R2',
          },

          dbi =>
          $self->dbi_config(),

          authen_cookie =>
          { name       => 'VegGuide-user',
            path       => '/',
            mac_secret => $self->authen_secret(),
          },

          'Log::Dispatch' => $self->_log_config(),
        );

    $config{root} = $self->share_dir();

    unless ( $self->is_production() )
    {
        $config{static} = { dirs         => [ qw( images js css static w3c ) ],
                            include_path => [ __PACKAGE__->var_lib_dir(),
                                              __PACKAGE__->share_dir(),
                                            ],
                            debug => 1,
                          };
    }

    return \%config;
}

{
    my %DatePatterns =
        ( 'hourly'  => 'yyyy-MM-dd-HH',
          'daily'   => 'yyyy-MM-dd',
          'weekly'  => 'yyyy-ww',
          'monthly' => 'yyyy-MM',
        );

    sub _log_config
    {
        my $self = shift;

        my @loggers;
        if ( $self->is_production() )
        {
            if ( $ENV{MOD_PERL} )
            {
                require Apache2::ServerUtil;

                push @loggers, { class     => 'ApacheLog',
                                 name      => 'ApacheLog',
                                 min_level => 'warning',
                                 apache    => Apache2::ServerUtil->server(),
                                 callbacks => sub { my %m = @_;
                                                    return 'r2: ' . $m{message} },
                               };
            }
            else
            {
                require Log::Dispatch::FileRotate;

                my $pattern = $self->_config_hash()->{log}{rotation};
                $pattern = $DatePatterns{$pattern}
                    if $DatePatterns{$pattern};

                push @loggers, { class       => 'FileRotate',
                                 name        => 'FileRotate',
                                 min_level   => 'warning',
                                 max         => $self->_config_hash()->{log}{max_files} || 52,
                                 DatePattern => $pattern || $DatePatterns{weekly},
                               };
            }
        }
        else
        {
            push @loggers, { class     => 'Screen',
                             name      => 'Screen',
                             min_level => 'debug',
                           };
        }

        return \@loggers;
    }
}

sub _dbi_config
{
    return { user => 'root' };
}

sub _mason_config
{
    my $self = shift;

    my %config =
        ( comp_root  => $self->share_dir()->subdir( 'mason' ),
          data_dir   => $self->cache_dir()->subdir( 'mason', 'web' ),
          error_mode => 'fatal',
          in_package => 'R2::Mason',
          use_match  => 0,
        );

    if ( $self->is_production() )
    {
        $config{static_source} = 1;
        $config{static_source_touch_file} =
            $self->etc_dir()->file('mason-touch')->stringify();
    }

    return \%config;
}

sub _static_path_prefix
{
    my $self = shift;

    return unless $self->is_production();

    return read_file( $self->etc_dir()->file('revision')->stringify() );
}

sub _forgot_pw_secret
{
    my $self = shift;

    return 'a big secret' unless $self->is_production();

    return $self->_config_hash()->{secrets}{forgot_pw};
}

sub _authen_secret
{
    my $self = shift;

    return 'a bigger secret' unless $self->is_production();

    return $self->_config_hash()->{secrets}{authen};
}

make_immutable();

no Moose;

1;
