package R2::Model::Account;

use strict;
use warnings;

use R2::Model::Domain;
use R2::Model::Fund;
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

    R2::Model::Fund->MakeDefaultsForAccount($self);
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
