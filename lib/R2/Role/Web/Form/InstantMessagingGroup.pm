package R2::Role::Web::Form::InstantMessagingGroup;

use Moose::Role;
use Chloro;

use R2::Types qw( DatabaseId NonEmptyStr );
use R2::Util qw( string_is_empty );

group messaging_provider => (
    repetition_key   => 'messaging_provider_id',
    is_empty_checker => '_messaging_provider_is_empty',
    (
        field messaging_provider_type_id => (
            isa      => DatabaseId,
            required => 1,
        ),
    ),
    (
        field screen_name => (
            isa      => NonEmptyStr,
            required => 1,
        ),
    ),
    (
        field note => (
            isa => NonEmptyStr,
        ),
    )
);

field messaging_provider_is_preferred => (
    isa      => NonEmptyStr,
    required => 1,
);

sub _messaging_provider_is_empty {
    my $self   = shift;
    my $params = shift;
    my $prefix = shift;
    my $group  = shift;

    my @keys = map { join q{.}, $prefix, $_->name() } $group->fields();

    return 1 unless ( grep { !string_is_empty( $params->{$_} ) } @keys ) > 1;
}

1;
