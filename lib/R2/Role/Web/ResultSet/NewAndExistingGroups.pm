package R2::Role::Web::ResultSet::NewAndExistingGroups;

use MooseX::Role::Parameterized;

use Lingua::EN::Inflect qw( PL_N );
use R2::Types qw( Str );

parameter group => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

role {
    my $p = shift;

    my $group = $p->group();

    method 'new_' . PL_N($group) => sub {
        my $self = shift;

        my $result = $self->results_as_hash();

        return [
            map  { $result->{$group}{$_} }
            grep {/^new/} keys %{ $result->{$group} }
        ];
    };

    method 'existing_' . PL_N($group) => sub {
        my $self = shift;

        my $result = $self->results_as_hash();

        return {
            map { $_ => $result->{$group}{$_} }
            grep { !/^new/ } keys %{ $result->{$group} }
        };
    };
};

1;
