package R2::Role::Web::Form::FromFey;

use MooseX::Role::Parameterized;

use Chloro::Types qw( ArrayRef Bool Int Num Str );

parameter table => (
    isa      => 'Fey::Table',
    required => 1,
);

parameter skip => (
    isa     => ArrayRef,
    default => sub { [] },
);

role {
    my $p     = shift;
    my %extra = @_;

    my $consumer = $extra{consumer};

    my $table = $p->table();

    my %skip;

    $skip{ $_->name() } = 1 for @{ $table->primary_key() };
    $skip{$_} = 1 for @{ $p->skip() };

    for my $column ( $table->columns() ) {
        next if $skip{ $column->name() };

        my %field = (
            name => $column->name(),
            isa  => _type_for_column( $column->generic_type() ),
        );

        $field{required} = 1
            unless $column->is_nullable()
                || (   $column->default()
                    && $column->default()->isa('Fey::Literal::String')
                    && $column->default()->string() eq q{} );

        $field{extractor} = '_datetime_from_str'
            if $field{isa} eq 'DateTime';

        $consumer->add_field( Chloro::Field->new(%field) );
    }
};

my %map = (
    text     => Str,
    blog     => Str,
    integer  => Int,
    float    => Num,
    boolean  => Bool,
    date     => 'DateTime',
    datetime => 'DateTime',
);

sub _type_for_column {
    my $sql_type = shift;

    return $map{$sql_type}
        || die "Cannot translate SQL type of $sql_type to Moose type";
}

1;

