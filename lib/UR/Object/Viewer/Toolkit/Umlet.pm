package UR::Object::Viewer::Toolkit::Umlet;

use warnings;
use strict;
require UR;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'UR::Object::Viewer::Toolkit::Text',
    has => [
        toolkit_name    => { is_constant => 1, value => "umlet" },
        toolkit_module  => { is_constant => 1, value => "(none)" },  # is this used anywhere?
    ]
);

# Behaving just like Text viewers should be ok...
# Maybe that means they should be combined somehow?

1;

=pod

=head1 NAME

UR::Object::Viewer::Toolkit::Umlet - Declaration of Umlet as a Viewer toolkit type

=head1 SYNOPSIS

Methods called by UR::Object::Viewer to get toolkit specific support for
common tasks.

=cut
