package R2::Schema::DonationSource;

use strict;
use warnings;

use R2::Schema::Account;
use R2::Schema::Donation;
use R2::Schema;
use R2::Types;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('DonationSource') );

    has_one( $schema->table('Account') );

    has_many 'donations' =>
        ( table => $schema->table('Donation') );

    has 'donation_count' =>
        ( is         => 'ro',
          isa        => 'R2::Type::PosOrZeroInt',
          lazy_build => 1,
        );

    class_has '_DonationCountSelect' =>
        ( is  => 'ro',
          isa => 'Fey::SQL::Select',
          lazy    => 1,
          default => sub { __PACKAGE__->_BuildDonationCountSelect() },
        );
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

sub _build_donation_count
{
    my $self = shift;

    my $select = $self->_DonationCountSelect();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    return
        $dbh->selectrow_arrayref( $select->sql($dbh),
                                  {},
                                  $self->donation_source_id() )->[0] || 0;
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
           ->where( $schema->table('Donation')->column('donation_source_id'),
                    '=', Fey::Placeholder->new() );

    return $select;
}

no Fey::ORM::Table;
no Moose;
no MooseX::ClassAttribute;

__PACKAGE__->meta()->make_immutable();

1;

__END__
