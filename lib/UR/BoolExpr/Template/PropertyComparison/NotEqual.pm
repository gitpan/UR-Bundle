
package UR::BoolExpr::Template::PropertyComparison::NotEqual;

use strict;
use warnings;
use UR;

UR::Object::Type->define(
    class_name  => __PACKAGE__, 
    is => ['UR::BoolExpr::Template::PropertyComparison'],
);

sub evaluate_subject_and_values {
    my $self = shift;
    my $subject = shift;
    my $comparison_value = shift;    
    my $property_name = $self->property_name;    
    my $property_value = $subject->$property_name;
    no warnings;
    return ($property_value ne $comparison_value ? 1 : '');
}


1;

=pod

=head1 NAME

UR::BoolExpr::Template::PropertyComparison::NotEqual - Perform a not-equal test

=cut
