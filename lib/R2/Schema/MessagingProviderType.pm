package R2::Schema::MessagingProviderType;

use strict;
use warnings;
use namespace::autoclean;

use R2::Schema;
use R2::Types qw( Str );
use R2::Util qw( string_is_empty );
use URI::Template;

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( validated_list );

{
    my $schema = R2::Schema->Schema();

    has_policy 'R2::Schema::Policy';

    has_table( $schema->table('MessagingProviderType') );

    my @uri_types = qw(
        add_uri
        chat_uri
        status_uri
        call_uri
        video_uri
    );

    sub URITypes { @uri_types }

    for my $type (@uri_types) {
        __PACKAGE__->meta()->add_method(
            $type => sub {
                my $self = shift;
                $self->_fill_uri( $type, screen_name => shift );
            }
        );
    }

    my @templates = map { $_ . '_template' } @uri_types;
    #<<<
    transform @templates
        => inflate {
            return if string_is_empty( $_[1] );
            URI::Template->new( $_[1] );
        }
        => deflate {
            defined $_[1] && ref $_[1] ? $_[1]->as_string() : $_[1]
        };
    #>>>

    class_has '_SelectAllSQL' => (
        is      => 'ro',
        isa     => 'Fey::SQL::Select',
        lazy    => 1,
        builder => '_BuildSelectAllSQL',
    );
}

{
    my @Providers = (
        {
            name              => 'Yahoo',
            chat_uri_template => 'ymsgr:sendim?{screen_name}',
            status_uri_template =>
                'http://opi.yahoo.com/yahooonline/u={screen_name}/m=g/t=2/l=us/opi.jpg',
        }, {
            name              => 'AIM',
            chat_uri_template => 'aim:goim?screenname={screen_name}',
            add_uri_template  => 'aim:addbudy?screenname={screen_name}',
            status_uri_template =>
                'http://api.oscar.aol.com/presence/icon?k={Config.aim_key}&t={screen_name}',
        }, {
            name              => 'Google Talk',
            chat_uri_template => 'gtalk:chat?jid={screen_name}',
        }, {
            name => 'ICQ',
        }, {
            name              => 'Skype',
            add_uri_template  => 'skype:{screen_name}?add',
            chat_uri_template => 'skype:{screen_name}?chat',
            call_uri_template => 'skype:{screen_name}?call',
            status_uri_template =>
                'http://mystatus.skype.com/mediumicon/{screen_name}',
        }, {
            name               => 'Windows Live Messenger',
            add_uri_template   => 'msnim:add?contact={screen_name}',
            chat_uri_template  => 'msnim:chat?contact={screen_name}',
            call_uri_template  => 'msnim:voice?contact={screen_name}',
            video_uri_template => 'msnim:video?contact={screen_name}',
            status_uri_template =>
                'http://messenger.services.live.com/users/{screen_name}@apps.messenger.live.com/presenceimage',
        },
    );

    sub EnsureRequiredMessageProviderTypesExist {
        for my $provider (@Providers) {
            next if __PACKAGE__->new( name => $provider->{name} );

            __PACKAGE__->insert( %{$provider} );
        }
    }
}

{
    my %spec = (
        screen_name => { isa => Str },
    );

    sub _fill_uri {
        my $self = shift;
        my $type = shift;
        my ($screen_name) = validated_list( \@_, %spec );

        my $meth     = $type . '_template';
        my $template = $self->$meth();

        return unless $template;

        my %vars = ( screen_name => $screen_name );

        for my $var ( $template->variables() ) {
            if ( $var =~ /^Config\.(\w+)/ ) {
                my $key = $1;

                die "Invalid config key: $key"
                    unless R2::Config->can($key);

                $vars{$var} = R2::Config->instance()->$key();

                return if string_is_empty( $vars{$var} );
            }
            elsif ( $var ne 'screen_name' ) {
                die "Invalid URI template variable for messaging URI: $var";
            }
        }

        $template->process_to_string(%vars);
    }
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

sub _BuildSelectAllSQL {
    my $class = __PACKAGE__;

    my $select = R2::Schema->SQLFactoryClass()->new_select();

    my $schema = R2::Schema->Schema();

    #<<<
    $select
        ->select( $schema->table('MessagingProviderType') )
        ->from  ( $schema->tables('MessagingProviderType') )
        ->order_by( $schema->table('MessagingProviderType')->column('name') );
    #>>>
    return $select;

}

__PACKAGE__->meta()->make_immutable();

1;

__END__
