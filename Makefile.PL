use 5.010;
use strict;
use warnings FATAL => 'all';
use inc::Module::Install;

name     'Plack-App-AutoCRUD';
all_from 'lib/Plack/App/AutoCRUD.pm';
author   q{Laurent Dami <dami@cpan.org>};
license  'artistic2';

perl_version 5.006;

tests_recursive('t');

resources (
   homepage   => 'https://metacpan.org/author/DAMI',
   #IRC        => 'irc://irc.perl.org/#Plack-App-AutoCRUD',
   license    => 'http://www.perlfoundation.org/artistic_license_2_0',
   repository => 'git://github.com/damil/Plack-App-AutoCRUD.git',
   bugtracker => 'http://rt.cpan.org/NoAuth/Bugs.html?Dist=Plack-App-AutoCRUD',
);

configure_requires (
   'Module::Install' => 0,
);

build_requires (
   'Test::More' => 0,
);

requires (
  'Alien::GvaScript'               => 1.43,
  'Carp'                           => 0,
  'CGI::Expand'                    => 0,
  'Clone'                          => 0,
  'Cwd'                            => 0,
  'Data::Domain'                   => 0,
  'Data::Dumper'                   => 0,
  'DBI'                            => 0,
  'DBIx::DataModel'                => 2.42,
  'Encode'                         => 0,
  'Excel::Writer::XLSX'            => 0,
  'HTTP::Date'                     => 0,
  'JSON'                           => 0,
  'List::MoreUtils'                => 0,
  'Log::Dispatch'                  => 0,
  'Moose'                          => 0,
  'MooseX::NonMoose'               => 0,
  'MooseX::SemiAffordanceAccessor' => 0,
  'Path::Tiny'                     => 0,
  'Plack'                          => 0,
  'Scalar::Util'                   => 0,
  'SQL::Abstract::FromQuery'       => 0,
  'Template'                       => 0,
  'Time::HiRes'                    => 0,
  'Try::Tiny'                      => 0,
  'URI'                            => 0,
  'URI::Escape'                    => 0,
  'XML::Simple'                    => 0,
  'YAML::Any'                      => 0,
  'namespace::clean'               => 0,
);

install_as_cpan;
auto_install;
WriteAll;
