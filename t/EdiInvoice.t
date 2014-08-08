#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw( $Bin );

use Test::More tests => 2;

BEGIN { use_ok('Koha::Edifact') }

my $invoice_file = "$Bin/BLSINV337023.CEI";

my $invoice = Koha::Edifact->new( { filename => $invoice_file, } );

isa_ok( $invoice, 'Koha::Edifact' );
