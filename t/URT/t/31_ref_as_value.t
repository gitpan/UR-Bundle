#!/usr/bin/env perl

use Test::More;
use File::Basename;
use lib File::Basename::dirname(__FILE__)."/../..";
use URT; 
use strict;
use warnings;

plan tests => 22;

my $o = URT::ObjWithHash->create(myhash1 => { aaa => 111, bbb => 222 }, mylist => [ ccc => 333, ddd => 444 ]); 
my @h = ($o->myhash1, $o->mylist); 
#diag "data was: " . Data::Dumper::Dumper($o,@h);
is(ref($h[0]),'HASH', "got a hashref back");
is(ref($h[1]),'ARRAY', "got an arrayref back");
is_deeply($h[0],{ aaa => 111, bbb => 222 },"got correct values back for hashref");

#TODO: {
#    local $TODO = 'array seems to be out of order';
    
    is_deeply($h[1],[ ccc => 333, ddd => 444 ],"got correct values back for arrayref");
#};

# make sure things being associated with objects
# are not being copied in the constructor

class TestClassB {
    has   => [
        value => { is => 'String' },
    ],
};

class TestClassA {
    has   => [
        b_thing => { is => 'TestClassB' }
    ],
};

my $ax = TestClassA->create();
ok($ax, "Created TestClassA without b_thing");

my $bx = TestClassB->create( value => 'abcdfeg' );
ok($bx, "Created TestClassB with value");

ok($ax->b_thing($bx), "Set b_thing to TestClassB object");
is($ax->b_thing, $bx, "b_thing is TestClassB object");

my $ay = TestClassA->create(
    b_thing => $bx
);
ok($ay, "Created TestClassA with bx as b_thing");
is($ax->b_thing,$ay->b_thing, "ax->b_thing is ay->b_thing");

ok($bx->value('oyoyoy'), "Changed bx->value");
is($ax->b_thing->value, $ay->b_thing->value, "ax->b_thing value is ay->b_thing value");

my $by = TestClassB->create( value => 'zzzykk' );
ok($by, "Created TestClassB with value");

ok($ay->b_thing($by), "Changed ay b_thing to by");

isnt($ax->b_thing,$ay->b_thing,"ax b_thing is not ay b_thing");
isnt($ax->b_thing->value,$ay->b_thing->value,"ax->b_thing value is not ay->b_thing value");

class TestClassC {
    has => [ 
        foo => { is => 'ARRAY' }
    ]
};

my $c;
ok($c = TestClassC->create,"Created TestClassC with no properties");
ok($c->foo([qw{foo bar baz}]),"Set foo");
is_deeply($c->foo,[qw{foo bar baz}],'Checking array');

ok($c = TestClassC->create(
    foo => [qw{foo bar baz}]
),"Created TestClassC with foo arrayref");
is_deeply($c->foo,[qw{foo bar baz}],'Checking array for alpha-sort');

#TODO: {
#    local $TODO = 'somewhere, somehow PAP workflow does this....  so lets make sure it works';
    
    my $d;
    ok(eval { $d = TestClassC->create(
        foo => [
            $c,  ## first element is a ur object
            [  ## next is a psuedo hash, or something that looks like one
                { make => 1, perl => 2, mad => 3, at => 4, us => 5 },
                'this',
                'is',
                'a',
                'pseudo',
                'hash' 
            ]
        ]
    ) }, "created TestClassC with psuedo-hash like array");
#    diag "data was: " . Data::Dumper::Dumper($d);
#}
