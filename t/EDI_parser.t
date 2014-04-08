#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

BEGIN {
    use_ok('Koha::EDI::Parser');
}

my $class = 'Koha::EDI::Parser';

my $obj = $class->new();

isa_ok( $obj, $class );

