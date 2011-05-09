package R2::Schema;

use strict;
use warnings;
use namespace::autoclean;

use Fey::DBIManager::Source;
use Fey::Loader;
use Path::Class qw( file );
use R2::Config;
use Storable qw( store retrieve );

use Fey::ORM::Schema;

{
    my $source = _source();

    my $schema = _load_schema($source);

    has_schema $schema;

    __PACKAGE__->DBIManager()->add_source($source);
}

sub _source {
    if ( $ENV{R2_MOCK_SCHEMA} ) {
        my $source = Fey::DBIManager::Source->new( dsn => 'dbi:Mock:' );

        $source->dbh()->{HandleError} = sub { Carp::confess(shift); };

        return $source;
    }
    else {
        my $config = R2::Config->instance()->database_connection();
        return Fey::DBIManager::Source->new(
            %{$config},
            post_connect => \&_set_dbh_attributes,
        );
    }
}

# The caching will not be used in production, but it makes reloading the
# Catalyst dev server a bit quicker during development.
sub _load_schema {
    my $source = shift;

    my $storable_file
        = R2::Config->instance()->cache_dir()->file('R2.schema.storable');
    my $sql_file = file(
        file( $INC{'R2/Schema.pm'} )->dir(),
        '..', '..',
        'schema',
        'R2.sql'
    );

    if (   !R2::Config->instance()->is_production()
        && -f $storable_file
        && -f $sql_file
        && $storable_file->stat()->mtime() >= $sql_file->stat()->mtime() ) {

        return retrieve( $storable_file->stringify() );
    }
    else {
        die 'Cannot use Fey::Loader with a mock connection'
            if $source->dbh()->{Driver}{Name} eq 'Mock';

        my $schema = Fey::Loader->new( dbh => $source->dbh() )->make_schema();
        store( $schema, $storable_file->stringify() );
        return $schema;
    }
}

sub _set_dbh_attributes {
    my $dbh = shift;

    $dbh->{pg_enable_utf8} = 1;

    # In an ideal world, this would cause all non-binary data to be marked as
    # utf-8. See https://rt.cpan.org/Public/Bug/Display.html?id=40199 for
    # details.
    $dbh->do(q{SET CLIENT_ENCODING TO 'UTF8'});

    $dbh->do('SET TIME ZONE UTC');

    $dbh->{HandleError} = sub { Carp::confess(shift) };

    return;
}

sub LoadAllClasses {
    my $class = shift;

    for my $table ( $class->Schema()->tables() ) {
        my $class = 'R2::Schema::' . $table->name();

        ( my $path = $class ) =~ s{::}{/}g;

        eval "use $class";
        die $@ if $@ && $@ !~ /\Qcan't locate $path/i;
    }
}

__PACKAGE__->meta()->make_immutable();

1;

