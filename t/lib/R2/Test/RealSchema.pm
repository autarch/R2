package R2::Test::RealSchema;

use strict;
use warnings;

use lib 'inc';

use DBD::Pg;
use DBI;
use File::Slurp qw( read_file );
use Path::Class qw( file );
use Test::More;

my $DB_NAME = $ENV{HUDSON_URL} ? "R2Hudson_$ENV{BUILD_NUMBER}" : 'R2Test';

sub import {
    eval {
        DBI->connect(
            'dbi:Pg:dbname=template1',
            q{}, q{}, {
                RaiseError => 1,
                PrintError => 0,
                PrintWarn  => 0,
            }
        );
    };

    if ($@) {
        Test::More::plan skip_all =>
            'Cannot connect to the template1 database with no username or password';
        exit 0;
    }

    if ( _database_exists() ) {
        _clean_tables();
    }
    else {
        _recreate_database();
    }

    require R2::Config;

    # Need to explicitly override anything that might be found in an existing
    # config file
    R2::Config->instance()->_set_database_name($DB_NAME);
    R2::Config->instance()->_set_database_username(q{});
    R2::Config->instance()->_set_database_password(q{});

    _seed_data();
}

sub _database_exists {
    my $dbh = eval {
        DBI->connect(
            "dbi:Pg:dbname=$DB_NAME",
            q{}, q{}, {
                RaiseError         => 1,
                PrintError         => 0,
                PrintWarn          => 1,
                ShowErrorStatement => 1,
            },
        );
    };

    return if $@ || !$dbh;

    my ($version_insert) = grep {/INSERT INTO "Version"/} _ddl_statements();

    my ($expect_version) = $version_insert =~ /VALUES \((\d+)\)/;

    my $col
        = eval { $dbh->selectcol_arrayref(q{SELECT version FROM "Version"}) };

    return $col && defined $col->[0] && $col->[0] == $expect_version;
}

sub _recreate_database {
    diag("Creating $DB_NAME database");

    require R2::DatabaseManager;

    my $man = R2::DatabaseManager->new(
        db_name => $DB_NAME,
        drop    => 1,
        quiet   => 1,
    );

    $man->update_or_install_db();
}

sub _clean_tables {
    my $dbh = DBI->connect(
        "dbi:Pg:dbname=$DB_NAME",
        q{}, q{}, {
            RaiseError         => 1,
            PrintError         => 0,
            PrintWarn          => 1,
            ShowErrorStatement => 1,
        },
    );

    diag("Cleaning tables in existing $DB_NAME database");

    my @tables;
    for my $stmt ( _ddl_statements() ) {
        next unless $stmt =~ /^CREATE TABLE (\S+)/;

        my $table = $1;
        next if $table eq q{"Version"};

        push @tables, $table;
    }

    $dbh->do( 'TRUNCATE ' . ( join ', ', @tables ) . ' CASCADE' );
}

{
    my @DDL;

    sub _ddl_statements {
        return @DDL if @DDL;

        my $file = file(
            $INC{'R2/Test/RealSchema.pm'},
            '..', '..', '..', '..', '..',
            'schema',
            'R2.sql'
        );

        my $ddl = read_file( $file->resolve()->stringify() );

        for my $stmt ( split /\n\n+(?=^\S)/m, $ddl ) {
            $stmt =~ s/^--.+\n//gm;

            next unless $stmt =~ /^(?:CREATE|ALTER|INSERT)/;

            push @DDL, $stmt;
        }

        return @DDL;
    }
}

sub _seed_data {
    require R2::SeedData;

    R2::SeedData::seed_data();
}

1;
