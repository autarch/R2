package R2::Role::Context::Domain;

use strict;
use warnings;

use R2::Schema::Domain;

use Moose::Role;

has 'domain' => (
    is      => 'ro',
    isa     => 'R2::Schema::Domain',
    lazy    => 1,
    builder => '_build_domain',
);

sub _build_domain {
    my $self = shift;

    my $host = $self->request()->uri()->host();
    return R2::Schema::Domain->new( web_hostname => $host )
        or die "No domain found for hostname ($host)\n";
}

1;
