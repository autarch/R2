package R2::Schema::Donation;

use strict;
use warnings;

use R2::Schema::DonationSource;
use R2::Schema::DonationTarget;
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Donation') );

    has_one source =>
        ( table => $schema->table('DonationSource') );

    has_one target =>
        ( table => $schema->table('DonationTarget') );

    has_one( $schema->table('PaymentType') );

    has_one( $schema->table('Contact') );

}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
