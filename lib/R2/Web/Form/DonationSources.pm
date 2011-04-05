package R2::Web::Form::DonationSources;

use Moose;
use Chloro;

use namespace::autoclean;

use Moose::Meta::Class;
use R2::Role::Web::ResultSet::NewAndExistingGroups;
use R2::Types qw( Bool DatabaseId MonthAsNumber NonEmptyStr );

with 'R2::Role::Web::Form';

group donation_source => (
    repetition_field => 'donation_source_id',
    (
        field name => (
            isa      => NonEmptyStr,
            required => 1,
        )
    )
);

my $Class = Moose::Meta::Class->create_anon_class(
    superclasses => ['Chloro::ResultSet'],
    roles        => [
        R2::Role::Web::ResultSet::NewAndExistingGroups->meta()
            ->generate_role( parameters => { group => 'donation_source' } )
    ],
    cache => 1,
);

$Class->make_immutable();

sub _resultset_class { $Class->name() }

__PACKAGE__->meta()->make_immutable();

1;
