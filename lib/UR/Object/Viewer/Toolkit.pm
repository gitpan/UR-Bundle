
=pod

=head1 NAME

UR::Object::Viewer::Toolkit 

=head1 SYNOPSIS

$v1 = $obj->create_viewer(toolkit => "gtk");
$v2 = $obj->create_viewer(toolkit => "tk");

is($v1->_toolkit_delegate, "UR::Object::Viewer::Toolkit::Gtk");
is($v2->_toolkit_delegate, "UR::Object::Viewer::Toolkit::Tk");

=head1 DESCRIPTION

Each viewer delegates to one of these to interact with the toolkit environment

=cut

package UR::Object::Viewer::Toolkit;

use warnings;
use strict;
our $VERSION = $UR::VERSION;;

require UR;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'UR::Singleton',
    is_abstract => 1,
    has => [
        toolkit_name    =>  { is_abstract => 1, is_constant => 1 },
        toolkit_module  =>  { is_abstract => 1, is_constant => 1 },
    ],
);  

1;
