package Koha::EDI;
use strict;
use warnings;
use base qw(Exporter);
use DateTime;
use Carp;
use English qw{ -no_match_vars };
use Business::ISBN;
use Business::Edifact::Interchange;
use C4::Context;
use Koha::Database;
use C4::Acquisition qw( NewBasket NewOrderItem NewOrder);
use C4::Items qw(AddItemFromMarc);
use C4::Biblio qw( AddBiblio TransformKohaToMarc );
use Koha::EDI::Order;
use Koha::Edifact;

our @EXPORT_OK =
  qw( process_quote process_invoice create_edi_order get_edifact_ean );

sub create_edi_order {
    my $parameters = shift;
    my $basketno   = $parameters->{basketno};
    my $ean        = $parameters->{ean};
    my $branchcode = $parameters->{branchcode};
    my $noingest   = $parameters->{noingest};
    if ( !$basketno || !$ean ) {
        carp "create_edi_order called with no basketno or ean";
        return;
    }

    my $database = Koha::Database->new();
    my $schema   = $database->schema();

    my @orderlines = $schema->resultset('Aqorder')->search(
        {
            basketno => $basketno,
        }
    )->all;

    my $vendor = $schema->resultset('VendorEdiAccount')->search(
        {
            vendor_id => $orderlines[0]->basketno->booksellerid->id,
        }
    )->single;

    my $ean_search_keys = { ean => $ean, };
    if ($branchcode) {
        $ean_search_keys->{branchcode} = $branchcode;
    }
    my $ean_obj =
      $schema->resultset('EdifactEan')->search($ean_search_keys)->single;

    my $edifact = Koha::EDI::Order->new(
        { orderlines => \@orderlines, vendor => $vendor, ean => $ean_obj } );

    my $order_file = $edifact->encode();

    # ingest result
    if ($order_file) {
        if ($noingest) {    # allows scripts to produce test files
            return $order_file;
        }
        my $order = {
            message_type => 'ORDERS',
            raw_msg      => $order_file,
            vendor_id    => $vendor->vendor_id,
            status       => 'Pending',
            basketno     => $basketno,
            filename     => $edifact->filename(),
        };
        $schema->resultset('EdifactMessage')->create($order);
        return 1;
    }

    return;
}

sub process_invoice {
    my $invoice_message = shift;

    #TBD
    #    my $edi = Koha::Edifact->new( { transmission => $quote->raw_msg, } );
    #    my $messages = $edi->message_array();
    #    if ( @{$messages} && $invoice_message->vendor_id ) {
    #    }
    #    $invoice_message->status('received');
    #    $invoice_message->update;    # status and basketno link
    return;
}

# called on messages with status 'new'
sub process_quote {
    my $quote = shift;

    my $edi = Koha::Edifact->new( { transmission => $quote->raw_msg, } );
    my $messages = $edi->message_array();

    if ( @{$messages} && $quote->vendor_id ) {
        my $basketno =
          NewBasket( $quote->vendor_id, 0, $quote->filename, q{}, q{} . q{} );
        $quote->basketno($basketno);
        for my $msg ( @{$messages} ) {
            my $items  = $msg->lineitems();
            my $refnum = $msg->message_refno;

            for my $item ( @{$items} ) {
                quote_item( $item, $quote );
            }
        }
    }
    $quote->status('received');
    $quote->update;    # status and basketno link

    return;
}

sub quote_item {
    my ( $item, $quote ) = @_;

    my $ecost = discounted_price( $quote->vendor->discount, $item->price );

    # create biblio record
    my $bib_hash = {
        'biblioitems.cn_source' => 'ddc',
        'items.cn_source'       => 'ddc',
        'items.notforloan'      => -1,
        'items.cn_sort'         => q{},
    };
    my $value;
    if ( $value = $item->series ) {
        $bib_hash->{'biblio.seriestitle'} = $value;
    }

    if ( $value = $item->publisher ) {
        $bib_hash->{'biblioitems.publishercode'} = $value;
    }
    if ( $value = $item->publication_date ) {
        $bib_hash->{'biblioitems.publicationyear'} =
          $bib_hash->{'biblio.copyrightdate'} = $value;
    }

    if ( $value = $item->title ) {
        $bib_hash->{'biblio.title'} = $value;
    }
    if ( $value = $item->author ) {
        $bib_hash->{'biblio.author'} = $value;
    }
    if ( $value = $item->{item_number_id} ) {
        $bib_hash->{'biblioitems.isbn'} = $value;
    }
    if ( $value = $item->girfield('stock_category') ) {
        $bib_hash->{'biblioitems.itemtype'} = $value;
    }
    $bib_hash->{'items.booksellerid'} = $quote->vendor_id;
    if ( $value = $item->price ) {
        $bib_hash->{'items.price'} = $bib_hash->{'items.replacementprice'} =
          $value;
    }
    if ( $value = $item->girfield('stock_category') ) {
        $bib_hash->{'items.itype'} = $value;
    }
    if ( $value = $item->girfield('collection_code') ) {
        $bib_hash->{'items.location'} = $value;
    }

    my $budget = get_budget( $item->girfield('fund_allocation') );

    my $note = {};

    my $shelfmark =
      $item->girfield('shelfmark') || $item->girfield('classification') || q{};
    $bib_hash->{'items.itemcallnumber'} = $shelfmark;
    my $branch = $item->girfield('branch');
    $bib_hash->{'items.holdingbranch'} = $bib_hash->{'items.homebranch'} =
      $branch;
    my $bib_record = TransformKohaToMarc($bib_hash);

    my $bib = check_for_existing_bib( $item->{item_number_id} );
    if ( !defined $bib ) {
        $bib = {};
        ( $bib->{biblionumber}, $bib->{biblioitemnumber} ) =
          AddBiblio( $bib_record, q{} );
    }

    my $order_note = $item->{free_text};
    $order_note ||= q{};
    my $order_hash = {
        basketno                => $quote->basketno,
        uncertainprice          => 0,
        biblionumber            => $bib->{biblionumber},
        title                   => $item->title,
        quantity                => 1,
        biblioitemnumber        => $bib->{biblioitemnumber},
        rrp                     => $item->price,
        ecost                   => $ecost,
        sort1                   => q{},
        sort2                   => q{},
        booksellerinvoicenumber => $item->reference,
        listprice               => $item->price,
        branchcode              => $branch,
        budget_id               => $budget->budget_id,
        notes                   => $order_note,
    };

    my ( undef, $ordernumber ) = NewOrder($order_hash);

    # budget
    if ( C4::Context->preference('AcqCreateItem') eq 'ordering' ) {
        my $itemnumber;
        ( $bib->{biblionumber}, $bib->{biblioitemnumber}, $itemnumber ) =
          AddItemFromMarc( $bib_record, $bib->{biblionumber} );
        NewOrderItem( $itemnumber, $ordernumber );
    }
    return;
}

sub discounted_price {
    my ( $discount, $price ) = @_;
    return ( $price - ( ( $discount * $price ) / 100 ) );
}

sub check_for_existing_bib {
    my $isbn = shift;

    my $search_isbn = $isbn;
    $search_isbn =~ s/^\s*/%/;
    $search_isbn =~ s/\s*$/%/;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare(
'select biblionumber, biblioitemnumber from biblioitems where isbn like ?',
    );
    my $tuple_arr =
      $dbh->selectall_arrayref( $sth, { Slice => {} }, $search_isbn );
    if ( @{$tuple_arr} ) {
        return $tuple_arr->[0];
    }
    else {
        undef $search_isbn;
        $isbn =~ s/\-//g;
        if ( $isbn =~ m/(\d{13})/ ) {
            my $b_isbn = Business::ISBN->new($1);
            if ( $b_isbn && $b_isbn->is_valid ) {
                $search_isbn = $b_isbn->as_isbn10->as_string();
            }

        }
        elsif ( $isbn =~ m/(\d{9}[xX]|\d{10})/ ) {
            my $b_isbn = Business::ISBN->new($1);
            if ( $b_isbn && $b_isbn->is_valid ) {
                $search_isbn = $b_isbn->as_isbn13->as_string();
            }

        }
        if ($search_isbn) {
            $search_isbn = "%$search_isbn%";
            $tuple_arr =
              $dbh->selectall_arrayref( $sth, { Slice => {} }, $search_isbn );
            if ( @{$tuple_arr} ) {
                return $tuple_arr->[0];
            }
        }
    }
    return;
}

# returns a budget obj or undef
sub get_budget {
    my $budget_code = shift;
    my $database    = Koha::Database->new();
    my $schema      = $database->schema();

    # db does not ensure budget code is unque
    # other params TBD
    return $schema->resultset('Aqbudget')->single(
        {
            budget_code => $budget_code,
        }
    );
}

sub get_edifact_ean {

    # kludge we need to identify the correct ean to use at present
    # assuming we have one
    # breakdown by branch vendor with a default
    my $dbh = C4::Context->dbh;

    my $eans = $dbh->selectcol_arrayref('select ean from edifact_ean');

    return $eans->[0];
}

1;
