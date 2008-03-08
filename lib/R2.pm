package R2;

use strict;
use warnings;

our $VERSION = '0.01';

use Catalyst;
use Catalyst::Runtime '5.70';

use R2::Config;


my $Config;
BEGIN
{
    $Config = R2::Config->new();

    Catalyst->import( @{ $Config->catalyst_imports() } );
}

__PACKAGE__->config( name => 'R2',
                     %{ $Config->catalyst_config() },
                   );

#__PACKAGE__->request_class( 'R2::Request' );
#__PACKAGE__->response_class( 'R2::Response' );

__PACKAGE__->setup();

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
