package R2;

use strict;
use warnings;
use namespace::autoclean;

our $VERSION = '0.01';

use Catalyst::App::RoleApplicator;
use Catalyst::Plugin::Session;
use Catalyst::Request::REST::ForBrowsers;
use R2::Config;
use R2::Request;
use R2::Schema;
use R2::Web::Session;

use Moose;

my $Config;

BEGIN {
    extends 'Catalyst';

    $Config = R2::Config->instance();

    my @imports = qw(
        AuthenCookie
        +R2::Plugin::ErrorHandling
        Session::AsObject
        Session::State::URI
        +R2::Plugin::Session::Store::R2
        RedirectAndDetach
        SubRequest
        Unicode::Encoding
    );

    push @imports, 'Static::Simple'
        if $Config->serve_static_files();

    push @imports, 'StackTrace'
        unless $Config->is_production() || $Config->is_profiling();

    Catalyst->import(@imports);

    R2::Schema->LoadAllClasses();
}

with qw(
    R2::AppRole::Account
    R2::AppRole::Domain
    R2::AppRole::RedirectWithError
    R2::AppRole::User
);

{
    my %config = (
        name              => 'R2',
        default_view      => 'Mason',
        'Plugin::Session' => {
            expires => ( 60 * 5 ),

            # Need to quote it for Pg
            dbi_table        => q{"Session"},
            dbi_dbh          => 'R2::Plugin::Session::Store::R2',
            object_class     => 'R2::Web::Session',
            rewrite_body     => 0,
            rewrite_redirect => 1,
        },
        authen_cookie => {
            name       => 'R2-user',
            path       => '/',
            mac_secret => $Config->secret(),
        },
        encoding => 'UTF-8',
        root     => $Config->share_dir()->stringify(),
    );

    unless ( $Config->is_production() ) {
        $config{static} = {
            dirs         => [qw( files images js css static )],
            include_path => [
                map { $Config->$_()->stringify() }
                    qw( cache_dir var_lib_dir share_dir )
            ],
            debug => 1,
        };
    }

    __PACKAGE__->config(\%config);
}

__PACKAGE__->apply_request_class_roles('R2::Request');

R2::Schema->EnableObjectCaches();

__PACKAGE__->setup();

__PACKAGE__->meta()->make_immutable( replace_constructor => 1 );

1;

__END__

=head1 NAME

R2 - Catalyst based application

=head1 SYNOPSIS

    script/r2_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<R2::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Dave Rolsky,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
