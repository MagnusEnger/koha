#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
    use_ok('Koha::EDI::Account');
}

my $class = 'Koha::EDI::Account';

my $obj = $class->new({});

isa_ok($obj,$class);



