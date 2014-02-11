#!/usr/bin/perl

use warnings;
use strict;

use Rebus::EDI;

my $edi = Rebus::EDI->new();

my $result = $edi->retrieve_quotes;
