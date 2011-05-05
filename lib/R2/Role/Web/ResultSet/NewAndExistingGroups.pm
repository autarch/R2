package R2::Role::Web::ResultSet::NewAndExistingGroups;

use MooseX::Role::Parameterized;

use Lingua::EN::Inflect qw( PL_N );
use R2::Types qw( NonEmptyStr );
use R2::Util qw( string_is_empty );

parameter group => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

role {
    my $p = shift;

    my $group = $p->group();
    my $preferred = $group . '_is_preferred';

    my $_data_for = sub {
        my $key    = shift;
        my $result = shift;

        my $data = $result->{$group}{$key};

        if ( !string_is_empty( $result->{$preferred} ) ) {
            $data->{is_preferred} = $result->{$preferred} eq $key ? 1 : 0;
        }

        return $data;
    };

    method 'new_' . PL_N($group) => sub {
        my $self = shift;

        my $result = $self->results_as_hash();

        return [
            map  { $_data_for->( $_, $result ) }
            grep {/^new/} keys %{ $result->{$group} }
        ];
    };

    method 'existing_' . PL_N($group) => sub {
        my $self = shift;

        my $result = $self->results_as_hash();

        return {
            map { $_ => $_data_for->( $_, $result ) }
            grep { !/^new/ } keys %{ $result->{$group} }
        };
    };
};

1;
