package R2::Role::Web::ResultSet::FromSchema;

use MooseX::Role::Parameterized;

use Lingua::EN::Inflect qw( PL_N );
use R2::Types qw( ArrayRef ClassName NonEmptyStr );

parameter classes => (
    isa => ArrayRef [ClassName],
    required => 1,
);

parameter skip => (
    isa     => ArrayRef[NonEmptyStr],
    default => sub { [] },
);

role {
    my $p = shift;

    my %skip = map { $_ => 1 } @{ $p->skip() };

    for my $class ( @{ $p->classes() } ) {

        $class =~ /::(\w+)$/;
        my $method = lc $1 . '_params';

        my @cols = grep { !$skip{$_} }
            map { $_->name() } $class->Table()->columns();

        method $method => sub {
            my $self = shift;

            my $result = $self->results_as_hash();

            return map { $_ => $result->{$_} } grep { exists $result->{$_} } @cols;
        };
    }
};

1;
