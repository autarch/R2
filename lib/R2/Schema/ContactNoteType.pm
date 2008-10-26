package R2::Schema::ContactNoteType;

use strict;
use warnings;

use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('ContactNoteType') );

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $count =
        Fey::Literal::Function->new
            ( 'COUNT', @{ $schema->table('ContactNote')->primary_key() } );

    $select->select($count)
           ->from( $schema->tables('ContactNote') )
           ->where( $schema->table('ContactNote')->column('contact_note_type_id'),
                    '=', Fey::Placeholder->new() );

    has 'note_count' =>
        ( metaclass   => 'FromSelect',
          is          => 'ro',
          isa         => 'R2.Type.PosOrZeroInt',
          lazy        => 1,
          select      => $select,
          bind_params => sub { $_[0]->contact_note_type_id() },
        );
}

sub CreateDefaultsForAccount
{
    my $class   = shift;
    my $account = shift;

    $class->insert( description       => 'Made a note',
                    account_id        => $account->account_id(),
                    is_system_defined => 1,
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

sub is_updateable
{
    my $self = shift;

    return ! $self->is_system_defined();
}

sub is_deleteable
{
    my $self = shift;

    return 0 if $self->is_system_defined();

    return ! $self->note_count();
}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
