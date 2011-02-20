package R2::DatabaseManager;

use Moose;

use Path::Class qw( dir file );
use R2::Types qw( Bool HashRef Str );

extends 'Pg::DatabaseManager';

has '+app_name' => (
    default => 'R2',
);

has '+db_encoding' => (
    default => 'UTF-8',
);

has '+contrib_files' => (
    lazy    => 1,
    default => sub {
        ['citext.sql'];
    },
);

has _existing_config => (
    traits  => ['NoGetopt'],
    is      => 'ro',
    isa     => HashRef[Str],
    lazy    => 1,
    builder => '_build_existing_config',
);

has seed => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
    documentation =>
        'When this is true, a newly created database will be seeded with some basic initial data. Defaults to false.',
);

has populate => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
    documentation =>
        'When this is true, a newly created database will be seeded with a lot of data. Defaults to false.',
);

has truncate => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
    documentation =>
        'When this is true, all data in the database is wiped (use with seed or populate).',
);

# If this isn't done these attributes end up interleaved with attributes from
# the parent class when --help is run.
__PACKAGE__->meta()->get_attribute('seed')->_set_insertion_order(20);

sub _build_sql_file {
    return file( 'schema', 'R2.sql' );
}

sub _build_migrations_dir {
    return dir( 'inc', 'migrations' );
}

sub _build_existing_config {
    return {};
}

sub BUILD {
    my $self = shift;
    my $p    = shift;

    my $existing = $self->_existing_config();
    unless ( exists $p->{db_name} ) {
        die
            "No database name provided to the constructor and none can be found in an existing R2 config file."
            unless $existing->{name};

        $self->_set_db_name( $existing->{name} );
    }

    for my $attr (qw( username password host port )) {
        my $set = '_set_' . $attr;

        $self->$set( $existing->{$attr} )
            if defined $existing->{$attr};
    }

    return;
}

after update_or_install_db => sub {
    my $self = shift;

    if ( $self->seed() || $self->populate() ) {
        $self->_truncate_data() if $self->truncate();
        $self->_seed_data();
    }
};

sub _truncate_data {
    my $self = shift;

    $self->_setup_database_config();

    require R2::Schema;

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $db_name = $self->db_name();
    $self->_msg("Truncating the $db_name database");

    for my $table ( R2::Schema->Schema()->tables() ) {
        next if $table->name() eq 'Version';

        my $truncate = 'TRUNCATE TABLE ' . $table->sql($dbh) . ' CASCADE';
        $dbh->do($truncate);
    }
}

sub _seed_data {
    my $self = shift;

    $self->_setup_database_config();

    require R2::SeedData;

    my $db_name = $self->db_name();
    $self->_msg("Seeding the $db_name database");

    my $meth = $self->seed() ? 'seed_data' : 'seed_lots_of_data';
    R2::SeedData->$meth( verbose => !$self->quiet() );
}

{
    my $done;

    sub _setup_database_config {
        my $self = shift;

        return if $done;

        require R2::Config;

        my $config = R2::Config->instance();
        $config->_set_database_name( $self->db_name() );

        for my $key (qw( username password host port )) {
            if ( my $val = $self->$key() ) {
                my $set_meth = '_set_database_' . $key;

                $config->$set_meth($val);
            }
        }

        $done = 1;
    }
}

__PACKAGE__->meta()->make_immutable();

1;
