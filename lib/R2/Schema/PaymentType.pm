package R2::Schema::PaymentType;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema::Account;
use R2::Schema::Donation;
use R2::Schema;
use R2::Types qw( PosOrZeroInt );

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('PaymentType') );

    has_one( $schema->table('Account') );

    has_many 'donations' => ( table => $schema->table('Donation') );

    has 'donation_count' => (
        metaclass   => 'FromSelect',
        is          => 'ro',
        isa         => PosOrZeroInt,
        lazy        => 1,
        select      => __PACKAGE__->_BuildDonationCountSelect(),
        bind_params => sub { $_[0]->payment_type_id() },
    );
}

with 'R2::Role::Schema::HasDisplayOrder' =>
    { related_column => __PACKAGE__->Table()->column('account_id') };

sub CreateDefaultsForAccount {
    my $class   = shift;
    my $account = shift;

    for my $name ( 'Credit card', 'Check', 'Cash', 'In-kind (non-monetary)' )
    {
        $class->insert(
            name       => $name,
            account_id => $account->account_id(),
        );
    }
}

sub _BuildDonationCountSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $count = Fey::Literal::Function->new( 'COUNT',
        $schema->table('Donation')->column('donation_id') );

    $select->select($count)->from( $schema->tables('Donation') )->where(
        $schema->table('Donation')->column('payment_type_id'),
        '=', Fey::Placeholder->new()
    );

    return $select;
}

sub is_deletable {
    my $self = shift;

    return !$self->donation_count();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
