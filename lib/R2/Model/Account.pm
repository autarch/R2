package R2::Model::Account;

use strict;
use warnings;

use R2::Model::AddressType;
use R2::Model::Domain;
use R2::Model::Fund;
use R2::Model::MessagingProvider;
use R2::Model::PhoneNumberType;
use R2::Model::Schema;
# actually use'ing this module here causes some circular dependency madness
# use R2::Model::User;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    has_table( $schema->table('Account') );

    has_one( $schema->table('Domain') );

    has_one 'primary_user' =>
        ( table => $schema->table('User') );

    has_many 'funds' =>
        ( table    => $schema->table('Fund'),
          cache    => 1,
          order_by => [ $schema->table('Fund')->column('name') ],
        );

    has_many 'address_types' =>
        ( table    => $schema->table('AddressType'),
          cache    => 1,
          order_by => [ $schema->table('AddressType')->column('name') ],
        );

    has_many 'phone_number_types' =>
        ( table    => $schema->table('PhoneNumberType'),
          cache    => 1,
          order_by => [ $schema->table('PhoneNumberType')->column('name') ],
        );

    has_many 'messaging_providers' =>
        ( table    => $schema->table('MessagingProvider'),
          cache    => 1,
          order_by => [ $schema->table('MessagingProvider')->column('name') ],
        );
}


around 'insert' => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    my $sub = sub { my $account = $class->$orig(%p);

                    $account->_initialize();

                    return $account;
                  };

    return R2::Model::Schema->RunInTransaction($sub);
};

sub _initialize
{
    my $self = shift;

    R2::Model::Fund->CreateDefaultsForAccount($self);

    R2::Model::AddressType->CreateDefaultsForAccount($self);

    R2::Model::PhoneNumberType->CreateDefaultsForAccount($self);

    R2::Model::MessagingProvider->CreateDefaultsForAccount($self);
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
