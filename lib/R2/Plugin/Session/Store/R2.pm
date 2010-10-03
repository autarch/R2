package R2::Plugin::Session::Store::R2;

use strict;
use warnings;

use base 'Catalyst::Plugin::Session::Store::DBI';

use R2::Schema;

sub _session_dbic_connect {
    my $self = shift;

    $self->_session_dbh( R2::Schema->DBIManager()->default_source()->dbh() );
}

1;
