package R2::Schema::Domain;

use strict;
use warnings;

use R2::Schema::Account;
use R2::Schema;
use R2::Types;
use R2::Util qw( string_is_empty );
use URI::FromHash ();

use Fey::ORM::Table;
use MooseX::Params::Validate qw( validate );
use MooseX::ClassAttribute;

{
    my $schema = R2::Schema->Schema();

    has_table( $schema->table('Domain') );

    has_many 'accounts' =>
        ( table => $schema->table('Account') );

    class_has '_SelectAllSQL' =>
        ( is      => 'ro',
          isa     => 'Fey::SQL::Select',
          lazy    => 1,
          default => \&_MakeSelectAllSQL,
        );
}

has '_uri_scheme' =>
    ( is      => 'ro',
      isa     => 'Str',
      lazy    => 1,
      default => sub { $_[0]->requires_ssl() ? 'https' : 'http' },
    );


{
    my %spec = ( path     => { isa      => 'R2::Type::URIPath' },
                 query    => { isa      => 'HashRef',
                               default  => {},
                             },
                 fragment => { isa      => 'Str',
                               optional => 1,
                             },
               );
    sub uri
    {
        my ( $self, %p ) = validate( \@_, %spec );

        return URI::FromHash::uri( scheme => $self->_uri_scheme(),
                                   host   => $self->web_hostname(),
                                   %p,
                                 );
    }
}

sub All
{
    my $class = shift;

    my $select = $class->_SelectAllSQL();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    my $sth = $dbh->prepare( $select->sql($dbh) );

    return
        Fey::Object::Iterator->new( classes     => $class,
                                    handle      => $sth,
                                  );
}

sub _MakeSelectAllSQL
{
    my $class = __PACKAGE__;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Domain') )
           ->from( $schema->tables( 'Domain') )
           ->order_by( $schema->table('Domain')->column('web_hostname') );

    return $select;

}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
