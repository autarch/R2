package R2::Schema::DonationTarget;

use strict;
use warnings;

use R2::Schema::Account;
use R2::Schema::Donation;
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('DonationTarget') );

    has_one( $schema->table('Account') );

    has_many 'donations' =>
        ( table => $schema->table('Donation') );

    has 'donation_count' =>
        ( metaclass   => 'FromSelect',
          is          => 'ro',
          isa         => 'R2::Type::PosOrZeroInt',
          lazy        => 1,
          select      => __PACKAGE__->_BuildDonationCountSelect(),
          bind_params => sub { $_[0]->donation_target_id() },
        );
}


sub CreateDefaultsForAccount
{
    my $class   = shift;
    my $account = shift;

    $class->insert( name       => 'General Fund',
                    account_id => $account->account_id(),
                  );
}

sub _BuildDonationCountSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $count =
        Fey::Literal::Function->new( 'COUNT', $schema->table('Donation')->column('donation_id') );

    $select->select($count)
           ->from( $schema->tables( 'Donation' ) )
           ->where( $schema->table('Donation')->column('donation_target_id'),
                    '=', Fey::Placeholder->new() );

    return $select;
}

sub is_deletable
{
    my $self = shift;

    return ! $self->donation_count();
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
