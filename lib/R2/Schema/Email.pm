package R2::Schema::Email;

use strict;
use warnings;
use namespace::autoclean;

use Courriel;;
use Fey::Object::Iterator::FromSelect;
use HTML::FormatText;
use List::AllUtils qw( first );
use R2::Schema;
use R2::Types qw( Maybe Str );
use R2::Util qw( string_is_empty );
use Storable qw( thaw );

use Fey::ORM::Table;
use MooseX::ClassAttribute;

with 'R2::Role::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Email') );

    has_one from_contact => ( table => $schema->table('Contact') );

    has_one from_user => ( table => $schema->table('User') );

    has_one $schema->table('Account');

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

has courriel => (
    is       => 'ro',
    isa      => 'Courriel',
    init_arg => undef,
    lazy     => 1,
    default  => sub { thaw( $_[0]->email_object() ) },
);

has body_summary => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_body_summary',
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

sub _build_body_summary {
    my $self = shift;

    return first { !string_is_empty($_) }
        $self->_plain_body_summary(),
        $self->_html_body_summary(),
        $self->_no_body_text_message();
}

sub _plain_body_summary {
    my $self = shift;

    return unless defined $self->_plain_body_part();

    my $text = $self->_plain_body_part()->body_str();

    return if string_is_empty($text);

    return $self->_text_summary($text);
}

sub _html_body_summary {
    my $self = shift;

    return unless defined $self->_html_body_part();

    my $text = $self->_html_body_part()->body_str();

    return if string_is_empty($text);

    return $self->_text_summary( HTML::FormatText->format_string($text) );
}

sub _text_summary {
    my $self = shift;
    my $text = shift;

    my @paras = split /[\r\n]{1,}/, $text;

    my $summary = join "\n\n", @paras[ 0, 1 ];

    $summary .= "\n\n..." if @paras > 2;
}

sub _no_body_text_message {
    return '(This email does not have any text in its body.)';
}

sub _build_plain_body {
    my $self = shift;

    return $self->_first_part_with_type('text/plain');
}

sub _build_html_body {
    my $self = shift;

    return $self->_first_part_with_type('text/html');
}

sub _base_uri_path {
    my $self = shift;

    return
          $self->account()->_base_uri_path()
        . '/email/'
        . $self->email_id();
}

__PACKAGE__->meta()->make_immutable();

1;

__END__
