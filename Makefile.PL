
use warnings FATAL => 'all';
use strict;
use inc::Module::Install;

name     'UR';
license 'perl';
all_from 'lib/UR.pm';
perl_version '5.008';

# prereqs
requires 'version'              => '0.74';
requires 'Class::Autouse'       => '1.99_02';
requires 'Carp';
requires 'Sys::Hostname'        => '1.11';
requires 'File::Basename'       => '2.73';
requires 'Lingua::EN::Inflect'  => '1.88';
requires 'FreezeThaw'           => '0.43';
requires 'Date::Calc';
requires 'Date::Parse';
requires 'YAML';
requires 'Data::Compare'        => '0.13';
requires 'Text::Diff'           => '0.35';
requires 'DBI'                  => '1.601';
requires 'DBD::SQLite'          => '1.14';
#requires 'Moose'                => '0.31';

# things the tests need
build_requires 'Test::More' => '0.62';
build_requires 'Test::Fork' => '0.02';
#build_requires 'Test::Deep' => '0.096';
#build_requires 'Test::Differences' => '0.47';
#build_requires 'Test::Exception' => '0.21';

tests('t/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t');

WriteAll();

