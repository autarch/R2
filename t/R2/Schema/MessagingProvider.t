use strict;
use warnings;

use Test::More tests => 7;

use lib 't/lib';

use R2::Schema::MessagingProvider;

{
    my $provider = R2::Schema::MessagingProvider->new(
        messaging_provider_id => 1,
        name                  => 'Windows Live Messenger',
        add_uri_template      => 'msnim:add?contact={screen_name}',
        chat_uri_template     => 'msnim:chat?contact={screen_name}',
        call_uri_template     => 'msnim:voice?contact={screen_name}',
        video_uri_template    => 'msnim:video?contact={screen_name}',
        status_uri_template =>
            'http://mystatus.skype.com/mediumincon/{screen_name}',
        _from_query => 1,
    );

    is(
        $provider->add_uri('bubba'), 'msnim:add?contact=bubba',
        'add_uri() for provider'
    );

    is(
        $provider->status_uri('bubba'),
        'http://mystatus.skype.com/mediumincon/bubba',
        'status_uri() for provider'
    );
}

{
    my $provider = R2::Schema::MessagingProvider->new(
        messaging_provider_id => 1,
        name                  => 'Windows Live Messenger',
        add_uri_template      => q{},
        _from_query           => 1,
    );

    is(
        $provider->add_uri('bubba'), undef,
        'add_uri() for provider is undef'
    );
}

{

    package R2::Config;

    sub AIMKey { return 'abcdefg123456' }

    sub EmptyKey { }
}

{
    my $provider = R2::Schema::MessagingProvider->new(
        messaging_provider_id => 1,
        name                  => 'AIM',
        status_uri_template =>
            'http://api.oscar.aol.com/presence/icon?k={Config->AIMKey}&t={screen_name}',
        _from_query => 1,
    );

    is(
        $provider->status_uri('bubba'),
        'http://api.oscar.aol.com/presence/icon?k=abcdefg123456&t=bubba',
        'status_uri() for provider which needs config value'
    );
}

{
    my $provider = R2::Schema::MessagingProvider->new(
        messaging_provider_id => 1,
        name                  => 'AIM',
        status_uri_template =>
            'http://api.oscar.aol.com/presence/icon?k={Config->AIMKey}&t={screen_name}',
        add_uri_template  => '{Config->EmptyKey}&t={screen_name}',
        chat_uri_template => '{Config->NoSuchKey}&t={screen_name}',
        _from_query       => 1,
    );

    is(
        $provider->status_uri('bubba'),
        'http://api.oscar.aol.com/presence/icon?k=abcdefg123456&t=bubba',
        'status_uri() for provider which needs config value'
    );

    eval { $provider->add_uri('bubba') };
    like(
        $@, qr/No value for config key: EmptyKey/,
        'error when config key is empty'
    );

    eval { $provider->chat_uri('bubba') };
    like(
        $@, qr/Invalid config key: NoSuchKey/,
        'error when config key is not valid'
    );
}
