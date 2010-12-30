use strict;
use warnings;

use Test::More;

use lib 't/lib';

use R2::Test::FakeSchema;

use R2::Config;
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
    R2::Config->instance()->_set_aim_key('abcdefg123456');

    my $provider = R2::Schema::MessagingProvider->new(
        messaging_provider_id => 1,
        name                  => 'AIM',
        status_uri_template =>
            'http://api.oscar.aol.com/presence/icon?k={Config->aim_key}&t={screen_name}',
        _from_query => 1,
    );

    is(
        $provider->status_uri('bubba'),
        'http://api.oscar.aol.com/presence/icon?k=abcdefg123456&t=bubba',
        'status_uri() for provider which needs config value'
    );
}

{
    package R2::Config;

    sub empty_key { return undef }
}

{
    my $provider = R2::Schema::MessagingProvider->new(
        messaging_provider_id => 1,
        name                  => 'AIM',
        status_uri_template =>
            'http://api.oscar.aol.com/presence/icon?k={Config->aim_key}&t={screen_name}',
        add_uri_template  => '{Config->empty_key}&t={screen_name}',
        chat_uri_template => '{Config->no_such_key}&t={screen_name}',
        _from_query       => 1,
    );

    is(
        $provider->status_uri('bubba'),
        'http://api.oscar.aol.com/presence/icon?k=abcdefg123456&t=bubba',
        'status_uri() for provider which needs config value'
    );

    eval { $provider->add_uri('bubba') };
    like(
        $@, qr/No value for config key: empty_key/,
        'error when config key is empty'
    );

    eval { $provider->chat_uri('bubba') };
    like(
        $@, qr/Invalid config key: no_such_key/,
        'error when config key is not valid'
    );
}

done_testing();
