package R2::Schema::Person;

use strict;
use warnings;

use R2::Schema::Contact;
use R2::Schema::PersonMessaging;
use R2::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Schema->Schema();

    my $user_t = $schema->table('Person');

    has_table $user_t;

    has_one 'contact' =>
        ( table   => $schema->table('Contact'),
          handles => [ grep { ! __PACKAGE__->meta()->has_attribute($_) }
                       R2::Schema::Contact->DelegatableMethods(),
                     ],
        );

    has_one 'user' =>
        ( table => $schema->table('User'),
          undef => 1,
        );

    # XXX - this'd be nicer if it selected the messaging provider in
    # the same query
    has_many 'messaging' =>
        ( table       => $schema->table('PersonMessaging'),
          cache       => 1,
          select      => __PACKAGE__->_MessagingSelect(),
          bind_params => sub { $_[0]->person_id() },
        );
}


around 'insert' => sub
{
    my $orig  = shift;
    my $class = shift;
    my %p     = @_;

    my %person_p =
        map { $_ => delete $p{$_} } grep { $class->Table()->column($_) } keys %p;

    my $sub = sub { my $contact = R2::Schema::Contact->insert( %p, contact_type => 'Person' );

                    my $person =
                        $class->$orig( %person_p,
                                       person_id => $contact->contact_id(),
                                     );

                    $person->_set_contact($contact);

                    return $person;
                  };

    return R2::Schema->RunInTransaction($sub);
};

sub _MessagingSelect
{
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('PersonMessaging') )
           ->from( $schema->tables( 'PersonMessaging', 'MessagingProvider' ) )
           ->where( $schema->table('PersonMessaging')->column('person_id'),
                    '=', Fey::Placeholder->new() )
           ->order_by( $schema->table('MessagingProvider')->column('name'), 'ASC' );

    return $select;
}

sub friendly_name
{
    my $self = shift;

    return $self->first_name();
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
