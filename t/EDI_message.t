#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
    use_ok('Koha::EDI::Message');
}

my $class = 'Koha::EDI::Message';

my $obj = $class->new({});

isa_ok($obj,$class);


