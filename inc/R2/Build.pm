package R2::Build;

use strict;
use warnings;

use base 'Module::Build';


my %Requires =
    ( 'autodie'                                  => '0',
      'Catalyst'                                 => '5.80001',
      'Catalyst::Action::REST'                   => '0.5',
      'Catalyst::DR'                             => '0',
      'Catalyst::Plugin::AuthenCookie'           => '0.01',
      'Catalyst::Plugin::Log::Dispatch'          => '0',
      'Catalyst::Plugin::RedirectAndDetach'      => '0',
      'Catalyst::Plugin::Session'                => '0.17',
      'Catalyst::Plugin::Session::State'         => '0',
      'Catalyst::Plugin::Session::Store'         => '0',
      'Catalyst::Plugin::Session::Store::DBI'    => '0',
      'Catalyst::Plugin::StackTrace'             => '0.10',
      'Catalyst::Plugin::Static::Simple'         => '0.21',
      'Catalyst::Plugin::SubRequest'             => '0',
      'Catalyst::Plugin::Unicode'                => '0',
      'Catalyst::Request::REST::ForBrowsers'     => '0',
      'Catalyst::View::Mason'                    => '0.13',
      'Config::INI'                              => '0',
      'CSS::Minifier'                            => '0',
      'Cwd'                                      => '0',
      'Data::Validate::Domain'                   => '0',
      'Data::Validate::URI'                      => '0',
      'DateTime'                                 => '0',
      'DateTime::Format::Pg'                     => '0',
      'DateTime::Format::Strptime'               => '0',
      'DBD::Pg'                                  => '2.5.0',
      'DBI'                                      => '0',
      'Digest::SHA'                              => '0',
      'Email::Valid'                             => '0',
      'Exporter'                                 => '0',
      'Fey'                                      => '0.14',
      'Fey::DBIManager'                          => '0.07',
      'Fey::Loader'                              => '0.05',
      'Fey::ORM'                                 => '0.14',
      'File::Copy'                               => '0',
      'File::LibMagic'                           => '0',
      'File::Slurp'                              => '0',
      'File::Temp'                               => '0',
      'HTML::FillInForm'                         => '0',
      'HTML::DOM'                                => '0',
      'HTML::Tidy'                               => '0',
      'Image::Magick'                            => '0',
      'IPC::Run3'                                => '0',
      'JavaScript::Squish'                       => '0',
      'JSAN::ServerSide'                         => '0.04',
      'JSON::XS'                                 => '0',
      'Lingua::EN::Inflect'                      => '0',
      'List::AllUtils'                           => '0',
      'Locale::Country'                          => '0',
      'LWPx::ParanoidAgent'                      => '0',
      'Moose'                                    => '0.58',
      'MooseX::ClassAttribute'                   => '0.05',
      'MooseX::Params::Validate'                 => '0.07',
      'MooseX::Role::Parameterized'              => '0.04',
      'MooseX::Singleton'                        => '0.12',
      'Net::OpenID::Consumer'                    => '0',
      'Path::Class'                              => '0',
      'Params::Validate'                         => '0',
      'Sub::Name'                                => '0',
      'Sys::Hostname'                            => '0',
      'Time::HiRes'                              => '0',
      'URI::FromHash'                            => '0',
      'URI::Template'                            => '0',
    );

my %BuildRequires =
    ( 'DBD::Mock'       => '1.39',
      'Fey::ORM::Mock'  => '0',
      'Image::Size'     => '0',
      'Test::Exception' => '0',
      'Test::More'      => '0',
    );

sub new
{
    my $class = shift;

    return $class->SUPER::new
        ( license              => 'agpl3',
          module_name          => 'R2',
          requires             => \%Requires,
          build_requires       => \%BuildRequires,
          script_files         => [ glob('bin/*.pl') ],
          recursive_test_files => 1,
          meta_merge =>
              { resources =>
                    { homepage   => 'http://www.rapportware.org/',
                      repository => 'http://hg.urth.org/hg/R2',
                    },
              },
        );
}

sub ACTION_missing
{
    my $self = shift;

    my $prereqs = $self->prereq_failures();

    my %mods =
        ( map { $_ => 1 }
          map { keys %{ $prereqs->{$_} } }
          keys %{ $prereqs }
        );

    delete $mods{'Image::Magick'};

    print join ' ', sort keys %mods;
    print "\n";
}

sub valid_licenses
{
    my $self = shift;

    my $licenses = $self->SUPER::valid_licenses();

    $licenses->{agpl3} = 'http://opensource.org/licenses/agpl-v3.html';

    return $licenses;
}
