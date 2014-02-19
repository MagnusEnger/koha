package Koha::EDI::Parser;
use strict;
use warnings;
use parent qw/Exporter/;

use DateTime;
use Business::Edifact::Interchange;

our @EXPORT_OK = qw( parse_invoice parse_quote);

sub parse_invoice {
    my ( $self, $invoice ) = @_;
    my $parsed_invoice;
    my $datereceived => DateTime->now->strftime('%Y-%m-%d');
    my $edi = Business::Edifact::Interchange->new();
    $edi->parse_file("$self->{edidir}$invoice->{filename}");
    foreach my $m ( $edi->messages() ) {

        my $dt = DateTime->new(
            year  => substr( $m->{message_date}, 0, 4 ),
            month => substr( $m->{message_date}, 4, 2 ),
            day   => substr( $m->{message_date}, 6, 2 ),
        );
        my $ref_num      = $m->{ref_num};
        my $booksellerid = $invoice->{account_id};
        my $billingdate  = $dt->ymd;
        my $closedate    = $dt->ymd;

        my $delivery = 0;
        my $shippingfund;
        if ( $m->{allowance_or_charge} ) {
            foreach my $aoc ( @{ $m->{allowance_or_charge} } ) {
                if ( $aoc->{type} eq 'C' && $aoc->{service_code} eq 'DL' ) {
                    $delivery +=
                      $aoc->{amount}->[0]->{value};
                }
            }
            $shippingfund = _get_shipping_fund_id();
        }

        my $parsed_items = [];
        foreach my $item ( $m->items ) {
            my $item_charge = 0;
            if ( $item->{item_allowance_or_charge} ) {
                foreach my $aoc ( @{ $item->{item_allowance_or_charge} } ) {
                    if ( $aoc->{type} eq 'C' ) {
                        $item_charge += $aoc->{amount};
                    }
                }

            }
            my $item_tax_rate;
            if ( $item->{item_tax} ) {
                foreach my $t ( @{ $item->{item_tax} } ) {
                    if ( $t->{type_code} eq 'VAT' && $t->{rate} > 0 ) {
                        $item_tax_rate = $t->{rate};
                    }
                }
            }

            my $unit_price = 0;
            if ( $item->{price} ) {
                foreach my $p ( @{ $item->{price} } ) {
                    if ( $p->{qualifier} eq 'AAA' ) {
                        $unit_price = $p->{price};
                    }
                }
                $unit_price += $item_charge;
            }

            push @{$parsed_items},
              {
                unit_price   => $unit_price,
                quantity     => $item->{quantity_invoiced},
                datereceived => $datereceived,
                gstrate      => $item_tax_rate,
                supplier_ref => $item->{item_reference}[0][1],
              };
        }

        push @{$parsed_invoice},
          {
            ref_num               => $m->{ref_num},
            booksellerid          => $invoice->{account_id},
            billingdate           => $dt->ymd,
            shipmentdate          => $dt->ymd,
            shipmentcost          => $delivery,
            shipmentcost_budgetid => $shippingfund,
            items                 => $parsed_items,
          };
    }

    return $parsed_invoice;
}

sub parse_quote {
    my ( $self, $quote ) = @_;
    my @parsed_quote;
    my $edi = Business::Edifact::Interchange->new();
    $edi->parse_file( $self->{edidir} . $quote->{filename} );
    foreach my $m ( $edi->messages() ) {

        foreach my $item ( $m->items() ) {
            my $parsed_item = {
                author => $item->author_surname . ', '
                  . $item->author_firstname,
                title          => $item->title,
                isbn           => $item->{item_number},
                price          => $item->{price}->[0]->{price},
                publisher      => $item->publisher,
                year           => $item->date_of_publication,
                item_reference => $item->{item_reference}[0][1],
            };
            my $quantity = $item->{quantity};
            my $copies;
            for ( my $i = 0 ; $i < $item->{quantity} ; $i++ ) {

                #FIXME logic opaque here
                my $ftxlin;
                my $ftxlno;
                if ( $item->{free_text}->{qualifier} eq 'LIN' ) {
                    $ftxlin = $item->{free_text}->{text};
                }
                if ( $item->{free_text}->{qualifier} eq 'LNO' ) {
                    $ftxlno = $item->{free_text}->{text};
                }
                my $note;
                if ($ftxlin) {
                    $note = $ftxlin;
                }
                if ($ftxlno) {
                    $note = $ftxlno;
                }
                push @{$copies},
                  {
                    llo       => $item->{related_numbers}->[$i]->{LLO}->[0],
                    lfn       => $item->{related_numbers}->[$i]->{LFN}->[0],
                    lsq       => $item->{related_numbers}->[$i]->{LSQ}->[0],
                    lst       => $item->{related_numbers}->[$i]->{LST}->[0],
                    shelfmark => $item->shelfmark,
                    note      => $note,
                  };
            }
            $parsed_item->{copies} = $copies;
            push @parsed_quote, $parsed_item;
        }
    }
    return @parsed_quote;
}

# logic here needs looking at does not look like joined up thinking
sub _get_shipping_fund_id {
    my $fundcode = C4::Context->preference('EDIInvoicesShippingBudget');
    if ($fundcode) {
        my $dbh     = C4::Context->dbh;
        my $arr_ref = $dbh->selectcol_arrayref(
            'select budget_id from aqbudgets where budget_code=?',
            {}, $fundcode );
        return $arr_ref->[0];
    }
    return;
}

1;
