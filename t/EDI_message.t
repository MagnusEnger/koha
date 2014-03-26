#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 6;

BEGIN {
    use_ok('Koha::EDI::Message');
}

my $class = 'Koha::EDI::Message';

my $obj = $class->new({});

isa_ok($obj,$class);

my $msg =  $class->new( { id => 1, edi => 'message contents' });

is($msg->{id}, 1, "Id retrieval ok");
is($msg->{edi}, 'message contents', "Contents retrieval ok");

$msg->update({ id => 5, edi => 'different contents'});

is($msg->{id}, 1, "Id protected during update");
is($msg->{edi}, 'different contents', "Contents updated by update");
