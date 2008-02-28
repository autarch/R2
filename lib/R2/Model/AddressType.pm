package R2::Model::AddressType;

use strict;
use warnings;

use R2::Model::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    has_table( $schema->table('AddressType') );
}


sub CreateDefaultsForAccount
{
    my $class   = shift;
    my $account = shift;

    for my $name ( qw( Home Work Headquarters Branch ) )
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
