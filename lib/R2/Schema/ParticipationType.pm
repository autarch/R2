package R2::Schema::ParticipationType;

use Fey::ORM::Table;

use namespace::autoclean;

use R2::Types qw( PosOrZeroInt );

with 'R2::Role::Schema::DataValidator';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('ParticipationType') );

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $schema->table('ContactParticipation')->column('contact_id'),
    );

    #<<<
    $select
        ->select($count)
        ->from  ( $schema->table('ContactParticipation') )
        ->where ( $schema->table('ContactParticipation')->column('participation_type_id'),
                  '=', Fey::Placeholder->new() );
    #>>>
    has 'contact_count' => (
        metaclass   => 'FromSelect',
        is          => 'ro',
        isa         => PosOrZeroInt,
        lazy        => 1,
        select      => $select,
        bind_params => sub { $_[0]->address_type_id() },
    );
}

with 'R2::Role::Schema::HasDisplayOrder' =>
    { related_column => __PACKAGE__->Table()->column('account_id') };

sub CreateDefaultsForAccount {
    my $class   = shift;
    my $account = shift;

    for my $name (
        'Attended (Free)',
        'Attended (Paid)',
        'Organized',
        'Volunteered'
        ) {
        $class->insert(
            name       => $name,
            account_id => $account->account_id(),
        );
    }
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
