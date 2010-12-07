package R2::Schema::Domain;

use strict;
use warnings;

use Net::Interface;
use R2::Schema::Account;
use R2::Schema;
use R2::Types;
use R2::Util qw( string_is_empty );
use Socket qw( AF_INET );
use Sys::Hostname qw( hostname );
use URI::FromHash ();

use Fey::ORM::Table;
use MooseX::Params::Validate qw( validate );
use MooseX::ClassAttribute;

with 'R2::Role::Schema::URIMaker';

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('Domain') );

    has_many 'accounts' => ( table => $schema->table('Account') );

    has 'uri_params' => (
        is         => 'ro',
        isa        => 'HashRef',
        lazy_build => 1,
        init_arg   => undef,
    );

    class_has '_SelectAllSQL' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        lazy    => 1,
        default => \&_MakeSelectAllSQL,
    );
}

sub EnsureRequiredDomainsExist {
    my $class = shift;

    $class->_FindOrCreateDefaultDomain();
}

sub _FindOrCreateDefaultDomain {
    my $class = shift;

    my $hostname = $ENV{R2_HOSTNAME}
        || __PACKAGE__->_SystemHostname();

    my $domain = $class->new( web_hostname => $hostname );
    return $domain if $domain;

    return $class->insert( web_hostname => $hostname );
}

sub _SystemHostname {
    for my $name (
        hostname(),
        map { scalar gethostbyaddr( $_->address(), AF_INET ) }
        grep { $_->address() } Net::Interface->interfaces()
        ) {
        return $name if $name =~ /\.[^.]+$/;
    }

    die 'Cannot determine system hostname.';
}

sub All {
    my $class = shift;

    my $select = $class->_SelectAllSQL();

    my $dbh = $class->_dbh($select);

    return Fey::Object::Iterator::FromSelect->new(
        classes => $class,
        dbh     => $dbh,
        select  => $select,
    );
}

sub _MakeSelectAllSQL {
    my $class = __PACKAGE__;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('Domain') )
        ->from( $schema->tables('Domain') )
        ->order_by( $schema->table('Domain')->column('web_hostname') );

    return $select;

}

sub _build_uri_params {
    my $self = shift;

    my $scheme = $self->requires_ssl() ? 'https' : 'http';

    return {
        scheme => $scheme,
        host   => $self->web_hostname(),
    };
}

sub _base_uri_path {
    my $self = shift;

    return '/domain/' . $self->domain_id();
}

sub application_uri {
    my ( $self, %p ) = validate(
        \@_,
        path      => { isa => 'Str',     optional => 1 },
        fragment  => { isa => 'Str',     optional => 1 },
        query     => { isa => 'HashRef', default  => {} },
        with_host => { isa => 'Bool',    default  => 0 },
    );

    return $self->_make_uri(%p);
}

sub domain { $_[0] }

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
