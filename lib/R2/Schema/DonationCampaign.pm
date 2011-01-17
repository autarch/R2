package R2::Schema::DonationCampaign;

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

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('DonationCampaign') );

    has_one( $schema->table('Account') );

    has_many 'donations' => ( table => $schema->table('Donation') );

    query donation_count => (
        select      => __PACKAGE__->_BuildDonationCountSelect(),
        bind_params => sub { $_[0]->donation_campaign_id() },
    );
}

with 'R2::Role::Schema::HasDisplayOrder' =>
    { related_column => __PACKAGE__->Table()->column('account_id') };

sub CreateDefaultsForAccount {
    my $class   = shift;
    my $account = shift;

    $class->insert(
        name       => 'General Fund',
        account_id => $account->account_id(),
    );
}

sub _BuildDonationCountSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    my $count = Fey::Literal::Function->new(
        'COUNT',
        $schema->table('Donation')->column('donation_id')
    );

    #<<<
    $select
        ->select($count)
        ->from( $schema->tables('Donation') )
        ->where( $schema->table('Donation')->column('donation_campaign_id'),
                 '=', Fey::Placeholder->new() );
    #>>>
    return $select;
}

sub is_deletable {
    my $self = shift;

    return !$self->donation_count();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
