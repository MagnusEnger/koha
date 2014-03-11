#!/usr/bin/env perl

use strict;
use warnings;

use C4::Context;
use Test::More tests => 4;
use Test::MockModule;
use DBD::Mock

use_ok('Koha::EDI::Account');

my $t_context = Test::MockModule->new('C4::Context');
$t_context->mock (
    '_new_dbh',
    sub {
        my $dbh = DBI->connect( 'DBI:Mock:', q{}, q{} )
        || die "cannot create handle $DBI::errstr";
        $dbh->{mock_add_resultset} = [
            [ 'id', 'description', 'host', 'username', 'password', 'lasy_activity',
               'vendor_id', 'in_dir', 'san'],
             [ 5, 'test description', 'some.host.com', 'user1', 'pass1', undef, 11,
                 'xyz', 'S1234567890' ]
         ];
        return $dbh;
    }
);

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

my $acc2 = $class->new({ id => 5 });
$acc2->retrieve();

is( $acc2->id(), 5, 'id retrieval');




