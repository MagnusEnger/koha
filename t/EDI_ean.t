#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
    use_ok('Koha::EDI::Ean');
}

my $class = 'Koha::EDI::Ean';

my $obj = $class->new({ branchcode => 'TEST', ean => 'testean' });

isa_ok($obj,$class);



