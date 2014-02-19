package Koha::EDI::Formatter;
use strict;
use warnings;

use DateTime;
use Readonly;
use Business::ISBN;
use Koha::EDI::Util qw( cleanisbn );
use parent qw/Exporter/;

our @EXPORT_OK = qw( create_order_message );

sub create_order_message {
    my $order     = shift;
    my @datetime  = localtime;
    my $longyear  = ( $datetime[5] + 1900 );
    my $shortyear = sprintf '%02d', ( $datetime[5] - 100 );
    my $date      = sprintf '%02d%02d', ( $datetime[4] + 1 ), $datetime[3];
    my $hourmin   = sprintf '%02d%02d', $datetime[2], $datetime[1];
    my $year      = ( $datetime[5] - 100 );
    my $month     = sprintf '%02d', ( $datetime[4] + 1 );
    my $linecount = 0;
    my $segment   = 0;
    my $exchange  = int( rand(99999999999999) );
    my $ref       = int( rand(99999999999999) );

    ### opening header
    my $order_message = q{UNA:+.? '};

    ### Library SAN or EAN
    $order_message .= 'UNB+UNOC:2';
    if ( length( $order->{org_san} ) != 13 ) {
        $order_message .= q{+} . $order->{org_san} . ':31B'; # use SAN qualifier
    }
    else {
        $order_message .= q{+} . $order->{org_san} . ':14';  # use EAN qualifier
    }

    ### Vendor SAN or EAN
    if ( length( $order->{san_or_ean} ) != 13 ) {
        $order_message .=
          q{+} . $order->{san_or_ean} . ':31B';              # use SAN qualifier
    }
    else {
        $order_message .=
          q{+} . $order->{san_or_ean} . ':14';               # use EAN qualifier
    }

    ### date/time, exchange reference number
    $order_message .= "+$shortyear$date:$hourmin+$exchange++ORDERS+++EANCOM'";

    ### message reference number
    $order_message .= "UNH+$ref+ORDERS:D:96A:UN:EAN008'";
    $segment++;

    ### Order number and quote confirmation reference (if in response to quote)
    if ( $order->{quote_or_order} eq 'q' ) {
        $order_message .= "BGM+22V+$order->{order_id}+9'";
        $segment++;
    }
    else {
        $order_message .= "BGM+220+$order->{order_id}+9'";
        $segment++;
    }

    ### Date of message
    $order_message .= "DTM+137:$longyear$date:102'";
    $segment++;

    ### Library Address Identifier (SAN or EAN)
    if ( length( $order->{org_san} ) != 13 ) {
        $order_message .= "NAD+BY+$order->{org_san}::31B'";
        $segment++;
    }
    else {
        $order_message .= "NAD+BY+$order->{org_san}::9'";
        $segment++;
    }

    ### Vendor address identifier (SAN or EAN)
    if ( length( $order->{san_or_ean} ) != 13 ) {
        $order_message .= "NAD+SU+$order->{san_or_ean}::31B'";
        $segment++;
    }
    else {
        $order_message .= "NAD+SU+$order->{san_or_ean}::9'";
        $segment++;
    }

    ### Library's internal ID for Vendor
    $order_message .= "NAD+SU+$order->{provider_id}::92'";
    $segment++;

    ### Lineitems
    foreach my $lineitem ( @{ $order->{lineitems} } ) {
        $linecount++;
        my $note;
        my $isbn;
        if (   length $lineitem->{isbn} == 10
            || $lineitem->{isbn} =~ m/^978/
            || $lineitem->{isbn} !~ m/[|]/ )
        {
            $isbn = cleanisbn( $lineitem->{isbn} );
            $isbn = Business::ISBN->new($isbn);
            if ($isbn) {
                if ( $isbn->is_valid ) {
                    $isbn = ( $isbn->as_isbn13 )->isbn;
                }
                else {
                    $isbn = 0;
                }
            }
            else {
                $isbn = 0;
            }
        }
        else {
            $isbn = $lineitem->{isbn};
        }

        #FIXME shouldnt isbn be set in loop

        ### line number, isbn
        $order_message .= "LIN+$linecount++$isbn:EN'";
        $segment++;

        ### isbn as main product identification
        $order_message .= "PIA+5+$isbn:IB'";
        $segment++;

        ### title
        $order_message .=
          'IMD+L+050+:::' . _string35escape( $lineitem->{title} ) . q{'};
        $segment++;

        ### author
        $order_message .=
          'IMD+L+009+:::' . _string35escape( $lineitem->{author} ) . q{'};
        $segment++;

        ### publisher
        $order_message .=
          'IMD+L+109+:::' . _string35escape( $lineitem->{publisher} ) . q{'};
        $segment++;

        ### date of publication
        $order_message .=
          'IMD+L+170+:::' . _escape_reserved( $lineitem->{year} ) . q{'};
        $segment++;

        ### binding
        $order_message .=
          'IMD+L+220+:::' . _escape_reserved( $lineitem->{binding} ) . q{'};
        $segment++;

        ### quantity
        $order_message .=
          'QTY+21:' . _escape_reserved( $lineitem->{quantity} ) . q{'};
        $segment++;

        ### copies
        my $copyno = 0;
        foreach my $copy ( @{ $lineitem->{copies} } ) {
            my $gir_cnt = 0;
            $copyno++;
            $segment++;

            ### copy number
            $order_message .= sprintf 'GIR+%03d', $copyno;

            ### quantity
            $order_message .=
              q{+} . _escape_reserved( $lineitem->{quantity} ) . ':LQT';
            $gir_cnt++;

            ### Library branchcode
            $order_message .= q{+} . $copy->{llo} . ':LLO';
            $gir_cnt++;

            ### Fund code
            $order_message .= q{+} . $copy->{lfn} . ':LFN';
            $gir_cnt++;

            ### call number
            if ( $copy->{lcl} ) {
                $order_message .= q{+} . $copy->{lcl} . ':LCL';
                $gir_cnt++;
            }

            ### copy location
            if ( $copy->{lsq} ) {
                $order_message .=
                  q{+} . _string35escape( $copy->{lsq} ) . ':LSQ';
                $gir_cnt++;
            }

            ### circ modifier
            if ( $gir_cnt >= 5 ) {
                $order_message .= q{'GIR+} . sprintf '%03d',
                  $copyno . q{+} . $copy->{lst} . ':LST';
            }
            else {
                $order_message .= q{+} . $copy->{lst} . ':LST';
            }

            ### close GIR segment
            $order_message .= q{'};

            $note = $copy->{note};
        }

        ### Freetext item note
        if ($note) {
            $order_message .= "FTX+LIN+++:::$note'";
            $segment++;
        }

        ### price
        if ( $lineitem->{price} ) {
            $order_message .= "PRI+AAB:$lineitem->{price}'";
            $segment++;
        }

        ### currency
        $order_message .= "CUX+2:$lineitem->{currency}:9'";
        $segment++;

        ### Local order number
        $order_message .= "RFF+LI:$lineitem->{rff}'";
        $segment++;

        ### Quote reference (if in response to quote)
        if ( $order->{quote_or_order} eq 'q' ) {
            $order_message .= "RFF+QLI:$lineitem->{qli}" . q{'};
            $segment++;
        }
    }
    ### summary section header and number of lineitems contained in message
    $order_message .= q{UNS+S'};
    $segment++;

    ### Number of lineitems contained in the message_count
    $order_message .= "CNT+2:$linecount'";
    $segment++;

    ### number of segments in the message (+1 to include the UNT segment itself) and reference number from UNH segment
    $segment++;
    $order_message .= "UNT+$segment+$ref'";

    ### Exchange reference number from UNB segment
    $order_message .= "UNZ+1+$exchange'";
    return $order_message;
}

sub _string35escape {
    my $string = shift;
    $string = _escape_reserved($string);
    Readonly my $CHUNKLEN => 35;
    my $colon_string;
    my @sections;
    if ( length($string) > $CHUNKLEN ) {
        my ( $chunk, $stringlength ) = ( $CHUNKLEN, length $string );
        for ( my $counter = 0 ; $counter < $stringlength ; $counter += $chunk )
        {
            push @sections, substr $string, $counter, $chunk;
        }
        foreach my $section (@sections) {
            $colon_string .= "$section:";
        }
        chop $colon_string;
    }
    else {
        $colon_string = $string;
    }
    return $colon_string;
}

sub _escape_reserved {
    my $string = shift;
    if ($string) {
        $string =~ s/[?]/??/g;
        $string =~ s/'/?'/g;
        $string =~ s/:/?:/g;
        $string =~ s/[+]/?+/g;
        return $string;
    }
    else {
        return;
    }
}
1;
