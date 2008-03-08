package R2::Schema::PhoneNumberType;

use strict;
use warnings;

use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('PhoneNumberType') );
}


sub CreateDefaultsForAccount
{
    my $class   = shift;
    my $account = shift;

    for my $name ( qw( Home Office Cell ) )
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
