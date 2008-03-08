package R2::Schema::Account;

use strict;
use warnings;

use R2::Schema::AccountUserRole;
use R2::Schema::AddressType;
use R2::Schema::Domain;
use R2::Schema::Fund;
use R2::Schema::MessagingProvider;
use R2::Schema::PhoneNumberType;
use R2::Schema;

use Fey::ORM::Table;
use MooseX::Params::Validate qw( validatep );

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Account') );

    has_one( $schema->table('Domain') );

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

    return R2::Schema->RunInTransaction($sub);
};

sub _initialize
{
    my $self = shift;

    R2::Schema::Fund->CreateDefaultsForAccount($self);

    R2::Schema::AddressType->CreateDefaultsForAccount($self);

    R2::Schema::PhoneNumberType->CreateDefaultsForAccount($self);

    R2::Schema::MessagingProvider->CreateDefaultsForAccount($self);
}

{
    my %spec = ( user => { isa => 'R2::Schema::User' },
                 role => { isa => 'R2::Schema::Role' },
               );
    sub add_user
    {
        my $self            = shift;
        my ( $user, $role ) = validatep( \@_, %spec );

        R2::Schema::AccountUserRole->insert
            ( account_id => $self->account_id(),
              user_id    => $user->user_id(),
              role_id    => $role->role_id(),
            );
    }
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
