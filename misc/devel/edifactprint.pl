#!/usr/bin/perl
#
use strict;
use warnings;
use feature qw( say );
use File::Slurp;
# Debug and development tool
# print passed edifact files one segment per line

my @files = @ARGV;

foreach my $filename (@files) {
    my $edi_transmission = read_file($filename);

    # can we just remove \n \r check doc for allowable chars

    my @segments = segmentize($edi_transmission);

    display_segs( \@segments );
}

sub display_segs {
    my $seg_arr_ref = shift;

    foreach my $s ( @{$seg_arr_ref} ) {
        say $s;
    }
    return;
}

sub segmentize {
    my $raw = shift;

    my $re = qr{
(?>    # dont backtrack into this group
    \?.      # either the escape character
            # followed by any other character
     |      # or
     [^'?]   # a character that is neither escape
             # nor split
             )+
}x;
    my @segmented;
    while ( $raw =~ /($re)/g ) {
        push @segmented, "$1'";
    }
    return @segmented;
}
