#!/usr/bin/perl

use strict;
use warnings;
use C4::Context;
use POSIX qw/strftime/;

my $logdir = C4::Context->config('logdir');

my @logfiles = ( "$logdir/edi_ftp.log", "$logdir/edi_quote_error.log" );
my $rotate_size = 10485760;    # 10MB

my $currdate = strftime( '%Y%m%d', localtime );

foreach my $file (@logfiles) {
    if ( $rotate_size < -s $file ) {
        my $newname = "$file.$currdate";
        rename $file, $newname;
    }
}
