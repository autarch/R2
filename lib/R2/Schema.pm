package R2::Schema;

use strict;
use warnings;
use namespace::autoclean;

use Fey::DBIManager::Source;
use Fey::Loader;
use R2::Config;

use Fey::ORM::Schema;

if ($R2::Schema::TestSchema) {
    has_schema($R2::Schema::TestSchema);

    require DBD::Mock;

    my $source = Fey::DBIManager::Source->new( dsn => 'dbi:Mock:' );

    $source->dbh()->{HandleError} = sub { Carp::confess(shift); };

    __PACKAGE__->DBIManager()->add_source($source);
}
else {
    my $config = R2::Config->instance()->database_connection();

    my $source = Fey::DBIManager::Source->new(
        %{$config},
        post_connect => \&_set_dbh_attributes,
    );

    my $schema = Fey::Loader->new( dbh => $source->dbh() )->make_schema();

    has_schema $schema;

    __PACKAGE__->DBIManager()->add_source($source);
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
