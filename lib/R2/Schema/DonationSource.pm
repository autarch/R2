package R2::Schema::DonationSource;

use strict;
use warnings;

use R2::Schema::Account;
use R2::Schema::Donation;
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('DonationSource') );

    has_one( $schema->table('Account') );

    has_many 'donations' =>
        ( table => $schema->table('Donation') );
}


sub CreateDefaultsForAccount
{
    my $class   = shift;
    my $account = shift;

    for my $name ( qw( mail online ) )
    {
        $class->insert( name       => $name,
                        account_id => $account->account_id(),
                      );
    }
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
