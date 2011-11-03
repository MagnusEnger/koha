use strict;
use warnings;
use 5.10.1;
use C4::RoutingSlip::Copyright;

use Test::More tests => 6;                      # last test to print


my $class = 'C4::RoutingSlip::Copyright';

#my $obj = $class->new();
my $obj = $class->new( test => 1);

isa_ok($obj, $class);

$obj->get(id => 5);

cmp_ok( $obj->code(), 'eq', 'TEST', 'Code accessor test');
cmp_ok( $obj->txt(), 'eq', 'Test text', 'Text accessor test');

my $obj_array = $class->get_all( test => 1 );

my $count = @{$obj_array};
cmp_ok( $count, '==', 3, 'Correct size array returned');

cmp_ok( $obj_array->[1]->code(), 'eq', 'TEST', 'Code accessor works in array');
cmp_ok( $obj_array->[1]->txt(), 'eq', 'Test text', 'Text accessor works in array');

