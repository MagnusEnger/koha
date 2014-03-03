package Koha::EDI;

# Copyright 2012 Mark Gavillet

use strict;
use warnings;
use base qw( Exporter );

use Koha::EDI::Implementation qw(
  process_quotes
  process_invoices
  retrieve_orders
  retrieve_order_details
  create_order_file
);
use Koha::EDI::Formatter qw( create_order_message );
use Koha::EDI::Account;

our @EXPORT_OK = qw/ retrieve_quotes retrieve_invoices send_orders /;

=head1 NAME

Koha::EDI

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

sub retrieve_quotes {
    my @quotes;
    foreach my $vendor ( Koha::EDI::Account->ftp_accounts) {
        push @quotes. $vendor->download('QUOTE');
    }
    process_quotes( \@quotes );
    return;
}

sub retrieve_invoices {
    my @invoices;
    foreach my $vendor ( Koha::EDI::Account->ftp_accounts) {
        push @invoices. $vendor->download('INVOICE');
    }
    process_invoices( \@invoices );
    return;
}

sub send_orders {
    my ( $order_id, $ean ) = @_;
    my $orders = retrieve_orders($order_id);
    my $order_details = retrieve_order_details( $orders, $ean );
    foreach my $order ( @{$order_details} ) {

        my $order_message = create_order_message($order);
        my $order_file =
          create_order_file( $order_message, $order->{order_id} );
    }
    return;
}

1;
