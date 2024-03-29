package UR::Namespace::Command::Define::Datasource::Oracle;

use strict;
use warnings;
use UR;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => "UR::Namespace::Command::Define::Datasource::RdbmsWithAuth",
);

sub help_brief {
   "Add an Oracle data source to the current namespace."
}

sub _data_source_sub_class_name {
    'UR::DataSource::Oracle'
}

1;

