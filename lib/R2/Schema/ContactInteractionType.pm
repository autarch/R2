package R2::Schema::ContactInteractionType;

use strict;
use warnings;

use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('ContactInteractionType') );

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $count =
        Fey::Literal::Function->new
            ( 'COUNT', @{ $schema->table('ContactInteraction')->primary_key() } );

    $select->select($count)
           ->from( $schema->tables( 'ContactInteraction' ),  )
           ->where( $schema->table('ContactInteraction')->column('contact_interaction_type_id'),
                    '=', Fey::Placeholder->new() );

    has 'interaction_count' =>
        ( metaclass   => 'FromSelect',
          is          => 'ro',
          isa         => 'R2::Type::PosOrZeroInt',
          lazy        => 1,
          select      => $select,
          bind_params => sub { $_[0]->contact_interaction_type_id() },
        );
}

sub CreateDefaultsForAccount
{
    my $class   = shift;
    my $account = shift;

    $class->insert( system_name       => 'send_email',
                    description       => 'An email was sent to this contact',
                    is_system_defined => 1,
                    account_id        => $account->account_id(),
                  );

    $class->insert( description => 'Called this contact',
                    account_id  => $account->account_id(),
                  );

    $class->insert( description => 'Met with this contact',
                    account_id  => $account->account_id(),
                  );

    $class->insert( description => 'Contact attended an event',
                    account_id  => $account->account_id(),
                  );
}

around 'insert' => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    $p{system_name} = $p{description}
        unless exists $p{system_name};

    return $class->$orig(%p);
};

around 'update' => sub
{
    my $orig = shift;
    my $self = shift;
    my %p    = @_;

    if ( exists $p{description} )
    {
        $p{system_name} = $p{description}
            unless $self->is_system_defined();
    }

    return $self->$orig(%p);
};

sub is_deleteable
{
    my $self = shift;

    return 0 if $self->is_system_defined();

    return ! $self->interaction_count();
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
