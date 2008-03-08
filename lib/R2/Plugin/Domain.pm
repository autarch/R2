package R2::Plugin::Domain;

use strict;
use warnings;

use R2::Schema::Domain;


sub domain
{
    my $self = shift;

    return $self->{'R2::Plugin::Domain::domain'} ||= $self->_domain_for_request();
}

sub _domain_for_request
{
    my $self = shift;

    my $host = $self->request()->uri()->host();
    my $domain = R2::Domain->new( web_hostname => $host )
        or die "No domain found for hostname ($host)\n";

    return $domain;
}

1;
