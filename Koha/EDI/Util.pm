package Koha::EDI::Util;

use strict;
use warnings;
use Readonly;

use base qw( Exporter );

our @EXPORT_OK = qw( cleanisbn );

sub cleanisbn {
    my $isbn = shift;
    if ($isbn) {
        my $i = index $isbn, '(';
        if ( $i > 1 ) {
            $isbn = substr $isbn, 0, ( $i - 1 );
        }
        if ( $isbn =~ m/[|]/ ) {
            my @isbns = split /[|]/, $isbn;
            $isbn = $isbns[0];
        }

        $isbn =~ s/^\s+//;
        $isbn =~ s/\s+$//;
        return $isbn;
    }
    else {
        return;
    }
}
1;
