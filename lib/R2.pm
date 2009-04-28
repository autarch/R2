package R2;

use strict;
use warnings;

our $VERSION = '0.01';

use R2::Config;
use R2::Request;
use R2::Schema;

use Moose;

my $Config;

BEGIN
{
    extends 'Catalyst';

    $Config = R2::Config->new();

    Catalyst->import( @{ $Config->catalyst_imports() } );

    R2::Schema->LoadAllClasses();
}

with @{ $Config->catalyst_roles() };

__PACKAGE__->config( name => 'R2',
                     %{ $Config->catalyst_config() },
                   );

__PACKAGE__->request_class( 'R2::Request' );
#__PACKAGE__->response_class( 'R2::Response' );

R2::Schema->EnableObjectCaches();

__PACKAGE__->setup();

no Moose;

__PACKAGE__->meta()->make_immutable( replace_constructor => 1 );

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
