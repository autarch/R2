package R2::DatabaseManager;

use Moose;

use Path::Class qw( dir file );

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

sub _build_sql_file {
    return file( 'schema', 'R2.sql' );
}

sub _build_migrations_dir {
    return dir( 'inc', 'migrations' );
}

__PACKAGE__->meta()->make_immutable();

1;
