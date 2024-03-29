
package UR::Util;

use warnings;
use strict;
use Data::Dumper;

sub null_sub { }

sub used_libs {
    my @extra;
    for my $i (@INC) {
        last if $ENV{PERL5LIB} =~ /^$i\:/;
        push @extra, $i;
    }
    return @extra;
}

sub used_libs_perl5lib_prefix {
    my $prefix = "";
    for my $i (used_libs()) {
        $prefix .= "$i:";    
    }
    return $prefix;
}


sub deep_copy { 
    require Data::Dumper;
    local $Data::Dumper::Purity = 1;
    my $original = $_[0];
    # FIXME - this will cause Data::Dumper to emit a warning if $original contains a coderef...
    my $src = "no strict; no warnings;\n" . Data::Dumper::Dumper($original) . "\n\$VAR1;";
    my $copy = eval($src);
    return $copy;
}

# generate a method
sub _define_method
{
    my $class = shift;
    my (%opts) = @_;

    # create method name
    my $method = $opts{pkg} . '::' . $opts{property};

    # determine return value type
    my $retval;
    if (defined($opts{value}))
    {
        my $refval = ref($opts{value});
        $retval = ($refval) ? $refval : 'SCALAR';
    }
    else
    {
        $retval = 'SCALAR';
    }

    # start defining method
    my $substr = "sub $method { my \$self = shift; ";

    # set default value
    $substr .= "\$self->{$opts{property}} = ";
    my $dd = Data::Dumper->new([ $opts{value} ]);
    $dd->Terse(1); # do not print ``$VAR1 =''
    $substr .= $dd->Dump; 
    $substr .= " unless defined(\$self->{$opts{property}}); ";

    # array or scalar?
    if ($retval eq 'ARRAY') {
        if ($opts{access} eq 'rw') {
            # allow setting of array
            $substr .= "\$self->{$opts{property}} = [ \@_ ] if (\@_); ";
        }

        # add return value
        $substr .= "return \@{ \$self->{$opts{property}} }; ";
    }
    else { # scalar
        if ($opts{access} eq 'rw') {
            # allow setting of scalar
            $substr .= "\$self->{$opts{property}} = \$_[0] if (\@_); ";
        }

        # add return value
        $substr .= "return \$self->{$opts{property}}; ";
    }

    # end the subroutine definition
    $substr .= "}";

    # actually define the method
    no warnings qw(redefine);
    eval($substr);
    if ($@) {
        # fatal error since this is like a failed compilation
        die("failed to defined method $method {$substr}:$@");
    }
    return 1;
}

=over

=item generate_readwrite_methods

  UR::Util->generate_readwrite_methods
  (
      some_scalar_property = 1,
      some_array_property = []
  );

This method generates accessor/set methods named after the keys of its
hash argument.  The type of function generated depends on the default
value provided as the hash key value.  If the hash key is a scalar, a
scalar method is generated.  If the hash key is a reference to an
array, an array method is generated.

This method does not overwrite class methods that already exist.

=cut

sub generate_readwrite_methods
{
    my $class = shift;
    my %properties = @_;

    # get package of caller
    my $pkg = caller;

    # loop through properties
    foreach my $property (keys(%properties)) {
        # do not overwrite defined methods
        next if $pkg->can($property);

        # create method
        $class->_define_method
        (
            pkg => $pkg,
            property => $property,
            value => $properties{$property},
            access => 'rw'
        );
    }

    return 1;
}

=pod

=item generate_readwrite_methods_override

  UR::Util->generate_readwrite_methods_override
  (
      some_scalar_property = 1,
      some_array_property = []
  );

Same as generate_readwrite_function except that we force the functions
into the namespace even if the function is already defined

=cut

sub generate_readwrite_methods_override
{
    my $class = shift;
    my %properties = @_;

    # get package of caller
    my $pkg = caller;

    # generate the methods for each property
    foreach my $property (keys(%properties)) {
        # create method
        $class->_define_method
        (
            pkg => $pkg,
            property => $property,
            value => $properties{$property},
            access => 'rw'
        );
    }

    return 1;
}

=pod

=item generate_readonly_methods

  UR::Util->generate_readonly_methods
  (
      some_scalar_property = 1,
      some_array_property = []
  );

This method generates accessor methods named after the keys of its
hash argument.  The type of function generated depends on the default
value provided as the hash key value.  If the hash key is a scalar, a
scalar method is generated.  If the hash key is a reference to an
array, an array method is generated.

This method does not overwrite class methods that already exist.

=cut

sub generate_readonly_methods
{
    my $class = shift;
    my %properties = @_;

    # get package of caller
    my ($pkg) = caller;

    # loop through properties
    foreach my $property (keys(%properties)) {
        # do no overwrite already defined methods
        next if $pkg->can($property);

        # create method
        $class->_define_method
        (
            pkg => $pkg,
            property => $property,
            value => $properties{$property},
            access => 'ro'
        );
    }

    return 1;
}

1;

=pod

=head1 NAME

UR::Util - Collection of utility subroutines and methods

=head1 DESCRIPTION

This package contains subroutines and methods used by other parts of the 
infrastructure.  These subs are not likely to be useful to outside code.

=cut

