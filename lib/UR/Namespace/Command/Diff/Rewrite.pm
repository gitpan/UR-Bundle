
package UR::Namespace::Command::Diff::Rewrite;

use strict;
use warnings;
use UR;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => "UR::Namespace::Command",
);

sub help_description { 
    "Show the differences between current class headers and the results of a rewrite." 
}

*for_each_class_object = \&UR::Namespace::Command::Diff::for_each_class_object_delegate_used_by_sub_commands;

1;

