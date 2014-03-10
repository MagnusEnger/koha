#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;

BEGIN {
    use_ok('Koha::EDI::Account');
}

my $class = 'Koha::EDI::Account';

my $obj = $class->new({});

isa_ok($obj,$class);

my $hash_ref = {
    id => 101,
    description => 'blah blah',
    host => 'ftp.somevendor.com',
    username => 'xyz',
    password => 'pwd',
    vendor_id => 7,
    in_dir => 'yuk',
    san => 'SAN0123456789',
};

my $acct = $class->new($hash_ref);

is( $acct->id(), 101, 'id retrieval');



