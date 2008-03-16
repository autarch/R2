package R2;

use strict;
use warnings;

our $VERSION = '0.01';

use Catalyst;
use Catalyst::Request::REST::ForBrowsers;
use Catalyst::Runtime '5.70';

use R2::Config;
use R2::Schema;
BEGIN { R2::Schema->LoadAllClasses() }


my $Config;
BEGIN
{
    $Config = R2::Config->new();

    Catalyst->import( @{ $Config->catalyst_imports() } );
}

__PACKAGE__->config( name => 'R2',
                     %{ $Config->catalyst_config() },
                   );

__PACKAGE__->request_class( 'Catalyst::Request::REST::ForBrowsers' );
#__PACKAGE__->response_class( 'R2::Response' );

R2::Schema->EnableObjectCaches();

__PACKAGE__->setup();

{
package Catalyst::Engine::HTTP::Restarter::Watcher;

use IPC::Run3 qw( run3 );

# The existing test attempts to reload the file in the current
# process, which blows up for Moose classes made immutable, and all
# sorts of other things.
no warnings 'redefine';
sub _test {
    my ( $self, $file ) = @_;

    my @inc = map { ( '-I', $_ ) } @INC;

    my $err;

    run3( [ $^X, @inc, '-c', $file ],
          undef,
          undef,
          \$err,
        );

    return $err =~ /syntax OK/ ? 0 : $err;
}
}

1;

__END__

=head1 NAME

R2 - Catalyst based application

=head1 SYNOPSIS

    script/r2_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<R2::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Dave Rolsky,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
