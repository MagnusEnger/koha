package Koha::EDI::Order;

use strict;
use warnings;

use Carp;
use DateTime;
use Readonly;
use Business::ISBN;
use Encode qw(from_to);
use Koha::Database;
use C4::Budgets qw( GetBudget );

# order needs library_ean
#
Readonly::Scalar my $seg_terminator      => q{'};
Readonly::Scalar my $separator           => q{+};
Readonly::Scalar my $component_separator => q{:};
Readonly::Scalar my $release_character   => q{?};

Readonly::Scalar my $NINES_12  => 999_999_999_999;
Readonly::Scalar my $NINES_14  => 99_999_999_999_999;
Readonly::Scalar my $CHUNKSIZE => 35;

my $use_marc_based_description = 0;    # TBD A global config

sub new {
    my ( $class, $parameter_hashref ) = @_;

    my $self = {};
    if ( ref $parameter_hashref ) {
        $self->{orderlines} = $parameter_hashref->{orderlines};
        $self->{recipient}  = $parameter_hashref->{vendor};
        $self->{sender}     = $parameter_hashref->{ean};

        # convenient alias
        $self->{basket} = $self->{orderlines}->[0]->basketno;
        $self->{message_date} = DateTime->now( time_zone => 'local' );
    }

    bless $self, $class;
    return $self;
}

sub filename {
    my $self = shift;
    if ( !$self->{orderlines} ) {
        return;
    }
    my $filename = 'ordr' . $self->{basket}->basketno;
    $filename .= '.CEP';
    return $filename;
}

sub encode {
    my ($self) = @_;

    $self->{interchange_control_reference} = int rand($NINES_14);
    $self->{message_count}                 = 0;

    #    $self->{segs}; # Message segments

    $self->{transmission} = q{};

    $self->{transmission} .= $self->initial_service_segments();

    $self->{transmission} .= $self->user_data_message_segments();

    $self->{transmission} .= $self->trailing_service_segments();

    return $self->{transmission};
}

sub initial_service_segments {
    my $self = shift;

    #UNA service string advice - specifies standard separators
    my $segs = _const('service_string_advice');

    #UNB interchange header
    $segs .= $self->interchange_header();

    #UNG functional group header NOT USED
    return $segs;
}

sub interchange_header {
    my $self = shift;

    # syntax identifier
    my $hdr =
      'UNB+UNOC:3';    # controling agency character set syntax version number
                       # Interchange Sender
    $hdr .= _interchange_sr_identifier( $self->{sender}->ean,
        $self->{sender}->id_code_qualifier );    # interchange sender
    $hdr .= _interchange_sr_identifier( $self->{recipient}->san,
        $self->{recipient}->id_code_qualifier );    # interchange Recipient

    $hdr .= $separator;
    $hdr .= $self->{message_date}->format_cldr('yyMMdd:HHmm')
      ;                                             # DatTime of preparation
    $hdr .= $separator;
    $hdr .= $self->interchange_control_reference();
    $hdr .= $separator;

    # Recipents reference password not usually used in edifact
    $hdr .= q{+ORDERS};    # application reference
                           #Edifact does not usually include the following

#    $hdr .= $separator; # Processing priority  not usually used in edifact
#    $hdr .= $separator; # Acknowledgewment request : not usually used in edifact
#    $hdr .= q{+EANCOM} # Communications agreement id
#    $hdr .= q{+1} # Test indicator
    $hdr .= $seg_terminator;
    return $hdr;
}

sub user_data_message_segments {
    my $self = shift;

    #UNH message_header  :: seg count begins here
    $self->message_header();

    $self->order_msg_header();

    my $line_number = 0;
    foreach my $ol ( @{ $self->{orderlines} } ) {
        ++$line_number;
        $self->order_line( $line_number, $ol );
    }

    $self->message_trailer();

    my $data_segment_string = join q{}, @{ $self->{segs} };
    return $data_segment_string;
}

sub message_trailer {
    my $self = shift;

    # terminate the message
    $self->add_seg("UNS+S$seg_terminator");

    # CNT Control_Total
    # Could be (code = 1) total value of QTY segments
    # or ( code = 2 ) number of lineitems
    my $num_orderlines = @{ $self->{orderlines} };
    $self->add_seg("CNT+2:$num_orderlines$seg_terminator");

    # UNT Message Trailer
    my $segments_in_message =
      1 + @{ $self->{segs} };    # count incl UNH & UNT (!!this one)
    my $reference = $self->message_reference('current');
    $self->add_seg("UNT+$segments_in_message+$reference$seg_terminator");
    return;
}

sub trailing_service_segments {
    my $self    = shift;
    my $trailer = q{};

    #UNE functional group trailer NOT USED
    #UNZ interchange trailer
    $trailer .= $self->interchange_trailer();

    return $trailer;
}

sub interchange_control_reference {
    my $self = shift;
    if ( $self->{interchange_control_reference} ) {
        return sprintf '%014d', $self->{interchange_control_reference};
    }
    else {
        carp 'calling for ref of unencoded order';
        return 'NONE ASSIGNED';
    }
}

sub message_reference {
    my ( $self, $function ) = @_;
    if ( $function eq 'new' || !$self->{message_reference_no} ) {

        # unique 14 char mesage ref
        $self->{message_reference_no} = sprintf 'ME%012d', int rand($NINES_12);
    }
    return $self->{message_reference_no};
}

sub message_header {
    my $self = shift;

    $self->{segs} = [];          # initialize the message
    $self->{message_count}++;    # In practice alwaya 1

    my $hdr = q{UNH+} . $self->message_reference('new');
    $hdr .= _const('message_identifier');
    $self->add_seg($hdr);
    return;
}

sub interchange_trailer {
    my $self = shift;

    my $t = "UNZ+$self->{message_count}+";
    $t .= $self->interchange_control_reference;
    $t .= $seg_terminator;
    return $t;
}

sub order_msg_header {
    my $self = shift;
    my @header;

    # UNH  see message_header
    # BGM
    push @header, beginning_of_message( $self->{basket}->basketno );

    # DTM
    push @header, message_date_segment( $self->{message_date} );

    # NAD-RFF buyer supplier ids
    push @header,
      name_and_address(
        'BUYER',
        $self->{sender}->ean,
        $self->{sender}->id_code_qualifier
      );
    push @header,
      name_and_address(
        'SUPPLIER',
        $self->{recipient}->san,
        $self->{recipient}->id_code_qualifier
      );

    # repeat for for other relevant parties

    # CUX currency
    # ISO 4217 code to show default currency prices are quoted in
    # e.g. CUX+2:GBP:9'
    # TBD currency handling

    $self->add_seg(@header);
    return;
}

sub beginning_of_message {
    my $basketno = shift;
    my $document_message_no = sprintf '%011d', $basketno;

    #    my $message_function = 9;    # original 7 = retransmission
    # message_code values
    #      220 prder
    #      224 rush order
    #      228 sample order :: order for approval / inspection copies
    #      22C continuation  order for volumes in a set etc.
    #    my $message_code = '220';

    return "BGM+220+$document_message_no+9$seg_terminator";
}

sub name_and_address {
    my ( $party, $id_code, $id_agency ) = @_;
    my %qualifier_code = (
        BUYER    => 'BY',
        DELIVERY => 'DP',    # delivery location if != buyer
        INVOICEE => 'IV',    # if different from buyer
        SUPPLIER => 'SU',
    );
    if ( !exists $qualifier_code{$party} ) {
        carp "No qualifier code for $party";
        return;
    }
    if ( $id_agency eq '14' ) {
        $id_agency = '9';    # ean coded differently in this seg
    }

    return "NAD+$qualifier_code{$party}+${id_code}::$id_agency$seg_terminator";
}

sub order_line {
    my ( $self, $linenumber, $orderline ) = @_;

    my $database     = Koha::Database->new();
    my $schema       = $database->schema();
    my $biblionumber = $orderline->biblionumber->biblionumber;
    my @biblioitems  = $schema->resultset('Biblioitem')
      ->search( { biblionumber => $biblionumber, } );
    my $biblioitem = $biblioitems[0];    # makes the assumption there is 1 only
                                         # or else all have same details

    # LIN line-number in msg :: if we had a 13 digit ean we could add
    $self->add_seg( lin_segment( $linenumber, $biblioitem->isbn ) );

    # PIA isbn or other id
    $self->add_seg( additional_product_id( $biblioitem->isbn ) );

    # IMD biblio description
    if ($use_marc_based_description) {

        # get marc from biblioitem->marc

        # $ol .= marc_item_description($orderline->{bib_description});
    }
    else {    # use brief description
        $self->add_seg(
            item_description( $orderline->biblionumber, $biblioitem ) );
    }

    # QTY order quantity
    my $qty = join q{}, 'QTY+21:', $orderline->quantity, $seg_terminator;
    $self->add_seg($qty);

    # DTM Optional date constraints on delivery
    #     we dont currently support this in koha
    # GIR copy-related data special apps special processing goes there
    #if ( $orderline->{special_processing} ) {
    #    $self->add_seg( gir_segments( $orderline->{special_processing} ) );
    #}
    my @items = $schema->resultset('Item')->search(
        {
            biblionumber => $biblionumber,
            notforloan   => -1,
        }
    );
    my $budget = GetBudget( $orderline->budget_id );
    $self->add_seg( gir_segments( $budget->{budget_code}, @items ) );

    # TBD what if #items exceeds quantity

    # FTX free text for current orderline TBD
    #    dont really have a special instructions fiekd to encode here
    # PRI-CUX-DTM unit price on which order is placed : optional
    # RFF unique orderline reference no
    my $rff = join q{}, 'RFF+LI:', $orderline->ordernumber, $seg_terminator;
    $self->add_seg($rff);

    # LOC-QTY multiple delivery locations
    #TBD to specify extra elivery locs
    # NAD order line name and address
    #TBD Optionally indicate a name & address or order originator
    # TDT method of delivey ol-specific
    # TBD requests a special delivery option

    return;
}

# ??? Use the IMD MARC
sub marc_based_description {

    # this includes a much larger number of fields
    return;
}

sub item_description {
    my ( $bib, $biblioitem ) = @_;
    my $bib_desc = {
        author    => $bib->author,
        title     => $bib->title,
        publisher => $biblioitem->publishercode,
        year      => $biblioitem->publicationyear,
    };

    my @itm = ();

    # 009 Author
    # 050 Title   :: title
    # 080 Vol/Part no
    # 100 Edition statement
    # 109 Publisher  :: publisher
    # 110 place of pub
    # 170 Date of publication :: year
    # 220 Binding  :: binding
    my %code = (
        author    => '009',
        title     => '050',
        publisher => '109',
        year      => '170',
        binding   => '220',
    );
    for my $field (qw(author title publisher year binding )) {
        if ( $bib_desc->{$field} ) {
            my $data = encode_text( $bib_desc->{$field} );
            push @itm, imd_segment( $code{$field}, $data );
        }
    }

    return @itm;
}

sub imd_segment {
    my ( $code, $data ) = @_;

    my $seg_prefix = "IMD+L+$code+:::";

    # chunk_line
    my @chunks;
    while ( my $x = substr $data, 0, $CHUNKSIZE, q{} ) {
        if ( $x =~ s/([?]{1,2})$// ) {
            $data = "$1$data";    # dont breakup ?' ?? etc
        }
        push @chunks, $x;
    }
    my @segs;
    my $odd = 1;
    foreach my $c (@chunks) {
        if ($odd) {
            push @segs, "$seg_prefix$c";
        }
        else {
            $segs[-1] .= ":$c$seg_terminator";
        }
        $odd = !$odd;
    }
    if ( @segs && $segs[-1] !~ m/$seg_terminator$/o ) {
        $segs[-1] .= $seg_terminator;
    }
    return @segs;
}

sub gir_segments {
    my ( $budget_code, @onorderitems ) = @_;

    my @segments;
    my $sequence_no = 1;
    foreach my $item (@onorderitems) {
        my $seg = sprintf 'GIR+%03d', $sequence_no;
        $seg .= add_gir_identity_number( 'LLO', $item->homebranch->branchcode );
        $seg .= add_gir_identity_number( 'LFN', $budget_code );
        $seg .= add_gir_identity_number( 'LST', $item->itype );
        $seg .= add_gir_identity_number( 'LSQ', $item->location );
        $sequence_no++;
        push @segments, $seg;
    }
    return @segments;
}

sub add_gir_identity_number {
    my ( $number_qualifier, $number ) = @_;
    if ($number) {
        return "+${number}:${number_qualifier}";
    }
    return q{};
}

sub add_seg {
    my ( $self, @s ) = @_;
    foreach my $segment (@s) {
        if ( $segment !~ m/$seg_terminator$/o ) {
            $segment .= $seg_terminator;
        }
    }
    push @{ $self->{segs} }, @s;
    return;
}

sub lin_segment {
    my ( $line_number, $isbn ) = @_;
    my $isbn_string = q||;
    if ($isbn) {
        if ( $isbn =~ m/(978\d{10})/ ) {
            $isbn = $1;
        }
        elsif ( $isbn =~ m/(\d{9}[\dxX])/ ) {
            $isbn = $1;
        }
        else {
            undef $isbn;
        }
        if ($isbn) {
            my $b_isbn = Business::ISBN->new($isbn);
            if ( $b_isbn->is_valid ) {
                $isbn        = $b_isbn->as_isbn13->isbn;
                $isbn_string = "++$isbn:EN";
            }
        }
    }
    return "LIN+$line_number$isbn_string$seg_terminator";
}

sub additional_product_id {
    my $isbn_field = shift;
    my ( $product_id, $product_code );
    if ( $isbn_field =~ m/(\d{13})/ ) {
        $product_id   = $1;
        $product_code = 'EN';
    }
    elsif ( $isbn_field =~ m/(\d{9})[Xx\d]/ ) {
        $product_id   = $1;
        $product_code = 'IB';
    }

    # TBD we could have a manufacturers no issn etc
    if ( !$product_id ) {
        return;
    }

    # function id set to 5 states this is the main product id
    return "PIA+5+$product_id:$product_code$seg_terminator";
}

sub message_date_segment {
    my $dt = shift;

    # qualifier:message_date:format_code

    my $message_date = $dt->ymd(q{});    # no sep in edifact format

    return "DTM+137:$message_date:102$seg_terminator";
}

sub _const {
    my $key = shift;
    Readonly my %S => {
        service_string_advice => q{UNA:+.? '},
        message_identifier    => q{+ORDERS:D:96A:UN:EAN008'},
    };
    return ( $S{$key} ) ? $S{$key} : q{};
}

sub _interchange_sr_identifier {
    my ( $identification, $qualifier ) = @_;

    if ( !$identification ) {
        $identification = 'RANDOM';
        $qualifier      = '92';
        carp 'undefined identifier';
    }

    # 14   EAN International
    # 31B   US SAN (preferred)
    # also 91 assigned by supplier
    # also 92 assigned by buyer
    if ( $qualifier !~ m/^(?:14|31B|91|92)/xms ) {
        $qualifier = '92';
    }

    return "+$identification:$qualifier";
}

sub encode_text {
    my $string = shift;
    if ($string) {
        from_to( $string, 'utf8', 'iso-8859-1' );
        $string =~ s/[?]/??/g;
        $string =~ s/'/?'/g;
        $string =~ s/:/?:/g;
        $string =~ s/[+]/?+/g;
    }
    return $string;
}

1;
