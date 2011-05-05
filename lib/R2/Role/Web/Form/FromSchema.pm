package R2::Role::Web::Form::FromSchema;

use namespace::autoclean;

use MooseX::Role::Parameterized;

use Chloro::Error::Field;
use Chloro::Error::Form;
use R2::Types qw( ArrayRef ClassName NonEmptyStr );
use R2::Web::Util qw( table_to_chloro_fields );

parameter classes => (
    isa => ArrayRef [ClassName],
    required => 1,
);

parameter skip => (
    isa     => ArrayRef[NonEmptyStr],
    default => sub { [] },
);

has entity => (
    is        => 'ro',
    isa       => 'Fey::Object::Table',
    predicate => '_has_entity',
);

role {
    my $p     = shift;
    my %extra = @_;

    my $consumer = $extra{consumer};

    my %skip;

    my @tables = map { $_->Table() } @{ $p->classes() };

    $skip{$_} = 1 for @{ $p->skip() };

    $consumer->add_field($_)
        for map { table_to_chloro_fields( $_, \%skip ) } @tables;

    my $validate_against = $p->classes()->[0];

    return unless $validate_against->can('ValidateForInsert');

    around _make_resultset => sub {
        my $orig = shift;
        my $self = shift;

        my $resultset = $self->$orig(@_);

        my $invocant
            = $self->_has_entity() ? $self->entity() : $validate_against;

        my $meth
            = $self->_has_entity()
            ? 'validate_for_update'
            : 'ValidateForInsert';

        my $params = $resultset->results_as_hash();

        my @errors = $invocant->$meth( %{$params} );

        for my $error (@errors) {
            if ( my $field = delete $error->{field} ) {
                my $result = $resultset->result_for($field);
                $result->add_error(
                    Chloro::Error::Field->new(
                        field   => $self->meta()->get_field($field),
                        message => Chloro::ErrorMessage->new($error),
                    )
                );
            }
            else {
                $resultset->add_form_error(
                    Chloro::Error::Form->new(
                        message => Chloro::ErrorMessage->new($error)
                    )
                );
            }
        }

        return $resultset;
    };
};

1;
