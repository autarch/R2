package R2::Model::MessagingProvider;

use strict;
use warnings;

use R2::Model::Schema;

use Fey::ORM::Table;

{
    my $schema = R2::Model::Schema->Schema();

    has_table( $schema->table('MessagingProvider') );
}

{
    my @Defaults =
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
            status_uri_template  => 'http://mystatus.skype.com/mediumincon/{screen_name}',
          },
        );

    sub CreateDefaultsForAccount
    {
        my $class   = shift;
        my $account = shift;

        for my $def (@Defaults)
        {
            $class->insert( %{ $def },
                            account_id => $account->account_id(),
                          );
        }
    }
}

no Fey::ORM::Table;
no Moose;

__PACKAGE__->meta()->make_immutable();

1;

__END__
