package R2::Schema::MessagingProvider;

use strict;
use warnings;

use R2::Schema;
use R2::Util qw( string_is_empty );
use URI::Template;

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( validatep );

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('MessagingProvider') );

    my @uri_types = qw( add_uri_template chat_uri_template
                        status_uri_template call_uri_template
                        video_uri_template );

    for my $type (@uri_types)
    {
        ( my $meth = $type ) =~ s/_template$//;

        __PACKAGE__->meta()->add_method
            ( $meth =>
              sub { my $self = shift;
                    $self->_fill_uri( $type, screen_name => shift ) }
            );
    }

    transform @uri_types
        => inflate { return if string_is_empty( $_[1] ); URI::Template->new( $_[1] ) }
        => deflate { defined $_[1] && ref $_[1] ? $_[1]->as_string() : $_[1] };

    class_has '_SelectAllSQL' =>
        ( is         => 'ro',
          isa        => 'Fey::SQL::Select',
          lazy_build => 1,
        );
}

{
    my @Providers =
        ( { name                 => 'Yahoo',
            chat_uri_template    => 'ymsgr:sendim?{screen_name}',
            status_uri_template  => 'http://opi.yahoo.com/yahooonline/u={screen_name}/m=g/t=2/l=us/opi.jpg',
          },
          { name                 => 'AIM',
            chat_uri_template    => 'aim:goim?screenname={screen_name}',
            status_uri_template  => 'http://api.oscar.aol.com/presence/icon?k={Config->AIMKey}&t={screen_name}',
          },
          { name                 => 'Google Talk',
          },
          { name                 => 'ICQ',
          },
          { name                 => 'Skype',
            add_uri_template     => 'callto:{screen_name}?add',
            chat_uri_template    => 'callto:{screen_name}?chat',
            call_uri_template    => 'callto:{screen_name}?call',
            status_uri_template  => 'http://mystatus.skype.com/mediumincon/{screen_name}',
          },
          { name                 => 'Windows Live Messenger',
            add_uri_template     => 'msnim:add?contact={screen_name}',
            chat_uri_template    => 'msnim:chat?contact={screen_name}',
            call_uri_template    => 'msnim:voice?contact={screen_name}',
            video_uri_template   => 'msnim:video?contact={screen_name}',
            status_uri_template  =>
            'http://messenger.services.live.com/users/{screen_name}@apps.messenger.live.com/presenceimage',
          },
        );

    sub MakeDefaultProviders
    {
        for my $provider (@Providers)
        {
            next if __PACKAGE__->new( name => $provider->{name} );

            __PACKAGE__->insert( %{ $provider } );
        }
    }
}

sub _fill_uri
{
    my $self = shift;
    my $type = shift;

    my ($screen_name) = validatep( \@_, screen_name => { isa => 'Str' } );

    my $template = $self->$type();

    return unless $template;

    my %vars = ( screen_name => $screen_name );

    for my $var ( $template->variables() )
    {
        if ( $var =~ /^Config->(\w+)/ )
        {
            my $key = $1;

            die "Invalid config key: $key"
                unless R2::Config->can($key);

            $vars{$var} = R2::Config->$key();

            die "No value for config key: $key"
                unless defined $vars{$var};
        }
        elsif ( $var ne 'screen_name' )
        {
            die "Invalid URI template variable for messaging URI: $var";
        }
    }

    $template->process_to_string(%vars);
}

sub All
{
    my $class = shift;

    my $select = $class->_SelectAllSQL();

    my $dbh = R2::Schema->DBIManager()->default_source()->dbh();

    return
        Fey::Object::Iterator->new( classes => $class,
                                    dbh     => $dbh,
                                    select  => $select,
                                  );
}

sub _build__SelectAllSQL
{
    my $class = __PACKAGE__;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    $select->select( $schema->table('MessagingProvider') )
           ->from( $schema->tables( 'MessagingProvider') )
           ->order_by( $schema->table('MessagingProvider')->column('name') );

    return $select;

}

no Fey::ORM::Table;

__PACKAGE__->meta()->make_immutable();

1;

__END__
