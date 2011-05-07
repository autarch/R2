package R2::Web::Form::Participants;

use Moose;
use Chloro;

use namespace::autoclean;

use R2::Types qw( ArrayRef NonEmptySimpleStr NonEmptyStr PositiveInt );

with 'R2::Role::Web::Form', 'R2::Role::Web::Form::StartAndEndDates';

with 'R2::Role::Web::Form::FromSchema' => {
    classes => ['R2::Schema::ContactParticipation'],
    skip    => [ 'activity_id', 'contact_id' ],
};

field participants => (
    isa => ArrayRef [NonEmptySimpleStr],
    extractor => '_extract_participants',
    validator => '_validate_participants',
);

field contact_id => (
    isa => ArrayRef [PositiveInt],
);

sub _validate_participants {
    my $self = shift;
    my $participants = shift;
    my $params = shift;

    return if $params->{contact_id};

    return if $participants && @{$participants};

    return 'You must enter at least one participant.';
}

sub _extract_participants {
    my $self = shift;

    my ( $value, $name ) = $self->_extract_field_value(@_);

    return $value if ref $value;

    return (
        [ map { s/^\s+|\s+$//g; $_ } grep {/\S/} split /[\r\n]+/, $value ],
        $name,
    );
}

__PACKAGE__->meta()->make_immutable();

1;
