package R2::Role::Web::Group::FromSchema;

use namespace::autoclean;

use MooseX::Role::Parameterized;

use R2::Types qw( ArrayRef ClassName HashRef NonEmptyStr );
use R2::Web::Util qw( table_to_chloro_fields );
use Scalar::Util qw( blessed );

parameter group => (
    isa      => NonEmptyStr,
    required => 1,
);

parameter classes => (
    isa => ArrayRef [ClassName],
    required => 1,
);

parameter is_empty_checker => (
    isa => NonEmptyStr,
);

parameter skip => (
    isa => ArrayRef [NonEmptyStr],
    default => sub { [] },
);

role {
    my $p     = shift;
    my %extra = @_;

    my $consumer = $extra{consumer};

    my $validate_against = $p->classes()->[0];

    my $group_name = $p->group();
    my $repetition_key
        = $validate_against->Table()->primary_key()->[0]->name();

    my %skip;

    my @tables = map { $_->Table() } @{ $p->classes() };

    $skip{$_} = 1 for @{ $p->skip() };

    my $group = Chloro::Group->new(
        name           => $group_name,
        repetition_key => $repetition_key,
        (
            $p->is_empty_checker()
            ? ( is_empty_checker => $p->is_empty_checker() )
            : ()
        ),
        fields => [ map { table_to_chloro_fields( $_, \%skip ) } @tables ],
    );

    $consumer->add_group($group);

    if ( $validate_against->Table()->column('is_preferred') ) {
        $consumer->add_field(
            Chloro::Field->new(
                name     => $group_name . '_is_preferred',
                isa      => NonEmptyStr,
                required => 1,
            )
        );
    }

    return unless $validate_against->can('ValidateForInsert');

    my $validate_method = '_validate_' . $group_name . '_group';

    around _make_resultset => sub {
        my $orig = shift;
        my $self = shift;

        my $resultset = $self->$orig(@_);

        my $params = $resultset->results_as_hash();

        for my $key ( @{ $params->{$repetition_key} } ) {
            $self->$validate_method( $key, $params, $resultset );
        }

        return $resultset;
    };

    method $validate_method => sub {
        my $self      = shift;
        my $key       = shift;
        my $params    = shift;
        my $resultset = shift;

        my $invocant;
        my $meth;

        if ( $key =~ /^new/ ) {
            $invocant = $validate_against;
            $meth     = 'ValidateForInsert';
        }
        else {
            $invocant = $validate_against->new( $repetition_key => $key );
            die "Invalid key for $repetition_key in $validate_against - $key"
                unless $invocant;

            $meth = 'validate_for_update';
        }

        my @errors = $invocant->$meth( %{ $params->{$group_name}{$key} } );
        return unless @errors;

        my $group_key = $group_name . q{.} . $key;
        my $group_result = $resultset->result_for($group_key)
            or die "No group result for $group_key";

        for my $error (@errors) {
            if ( my $field = delete $error->{field} ) {
                # If we try to validate an insert when we've left a field out
                # of the form (like EmailAddress.contact_id), we'll get an
                # error, but it should be ignored.
                next if $skip{$field};

                my $result = $group_result->result_for($field);
                $result->add_error(
                    Chloro::Error::Field->new(
                        field   => $group->get_field($field),
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
    };
};

1;
