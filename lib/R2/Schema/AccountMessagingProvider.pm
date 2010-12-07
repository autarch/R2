package R2::Schema::AccountMessagingProvider;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema::Account;
use R2::Schema::MessagingProvider;
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('AccountMessagingProvider') );

    has_one( $schema->table('Account') );
    has_one( $schema->table('MessagingProvider') );
}

sub CreateDefaultsForAccount {
    my $class   = shift;
    my $account = shift;

    my $providers = R2::Schema::MessagingProvider->All();

    while ( my $provider = $providers->next() ) {
        $class->insert(
            account_id            => $account->account_id(),
            messaging_provider_id => $provider->messaging_provider_id(),
        );
    }
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
