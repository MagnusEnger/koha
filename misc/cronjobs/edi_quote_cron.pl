#!/usr/bin/perl

use warnings;
use strict;

use Koha::EDI;

my $edi = Koha::EDI->new();

my $result = $edi->retrieve_quotes;
