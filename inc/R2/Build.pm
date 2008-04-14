package R2::Build;

use strict;
use warnings;

use base 'Module::Build';


my %Requires =
    ( 'Catalyst'                                 => 5.7007,
      'Catalyst::Action::REST'                   => 0.5,
      'Catalyst::DR'                             => 0,
      'Catalyst::Plugin::AuthenCookie'           => 0.01,
      'Catalyst::Plugin::Cache::Store::FastMmap' => 0,
      'Catalyst::Plugin::Log::Dispatch'          => 0,
      'Catalyst::Plugin::RedirectAndDetach'      => 0,
      'Catalyst::Plugin::Session'                => 0.17,
      'Catalyst::Plugin::Session::State'         => 0,
      'Catalyst::Plugin::Session::Store'         => 0,
      'Catalyst::Plugin::Session::Store::DBI'    => 0,
      'Catalyst::Plugin::StackTrace'             => 0,
      'Catalyst::Plugin::Static::Simple'         => 0,
      'Catalyst::Plugin::SubRequest'             => 0,
      'Catalyst::Request::REST::ForBrowsers'     => 0,
      'Catalyst::View::Mason'                    => 0.13,
      'Config::INI'                              => 0,
      'CSS::Minifier'                            => 0,
      'Cwd'                                      => 0,
      'Data::Validate::Domain'                   => 0,
      'DateTime'                                 => 0,
      'DateTime::Format::Pg'                     => 0,
      'DateTime::Format::Strptime'               => 0,
      'DBD::Pg'                                  => '2.5.0',
      'DBI'                                      => 0,
      'Digest::SHA'                              => 0,
      'Exporter'                                 => 0,
      'Fey'                                      => 0.06,
      'Fey::DBIManager'                          => 0,
      'Fey::Loader'                              => 0,
      'Fey::ORM'                                 => 0.05,
      'File::Copy'                               => 0,
      'File::Slurp'                              => 0,
      'File::Spec'                               => 0,
      'File::Temp'                               => 0,
      'JavaScript::Squish'                       => 0,
      'JSAN::ServerSide'                         => 0.04,
      'JSON::XS'                                 => 0,
      'List::MoreUtils'                          => 0,
      'List::Util'                               => 0,
      'Locale::Country'                          => 0,
      'LWPx::ParanoidAgent'                      => 0,
      'Moose'                                    => 0,
      'MooseX::ClassAttribute'                   => 0,
      'MooseX::Params::Validate'                 => 0.05,
      'MooseX::Singleton'                        => 0.06,
      'Net::OpenID::Consumer'                    => 0,
      'Path::Class'                              => 0,
      'Params::Validate'                         => 0,
      'Sys::Hostname'                            => 0,
      'Time::HiRes'                              => 0,
      'URI::Template'                            => 0,
    );

sub new
{
    my $class = shift;

    return $class->SUPER::new
	( license         => 'perl',
	  module_name     => 'R2',
	  requires        => \%Requires,
	  script_files    => [ glob('bin/*') ],
          recursive_tests => 1,
	);
}
