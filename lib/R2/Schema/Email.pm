package R2::Schema::Email;

use strict;
use warnings;
use namespace::autoclean;

use Email::MIME;
use Fey::Object::Iterator::FromSelect;
use R2::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Email') );

    has_one from_contact => ( table => $schema->table('Contact') );

    has_one from_user => ( table => $schema->table('User') );

    class_has _ContactsSelect => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        builder => '_BuildContactsSelect',
    );

    has contacts => (
        is      => 'ro',
        isa     => 'Fey::Object::Iterator::FromSelect',
        lazy    => 1,
        builder => '_build_contacts',
    );
}

has email => (
    is      => 'ro',
    isa     => 'Email::MIME',
    lazy    => 1,
    default => sub { Email::MIME->new( $_[0]->raw_content() ) },
);

with 'R2::Role::Schema::Serializes';

sub _build_contacts {
    my $self = shift;

    my $select = $self->_ContactsSelect();

    my $dbh = $self->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes     => [qw( R2::Schema::Contact )],
        dbh         => $dbh,
        select      => $select,
        bind_params => [ $self->email_id() ],
    );
}

sub _BuildContactsSelect {
    my $class = shift;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->select( $schema->tables('Contact') )
        ->from  ( $schema->tables( 'Contact', 'ContactEmail' ) )
        ->where ( $schema->table('ContactEmail')->column('email_id'),
                  '=', Fey::Placeholder->new() )
        # XXX - should use order by defined in Search code
        ->order_by( $schema->table('Contact')->column('contact_id') );
    #>>>
    return $select;
}

sub _base_uri_path {
    my $self = shift;

    return '/email/' . $self->email_id();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
