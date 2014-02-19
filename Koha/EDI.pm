package Koha::EDI;

# Copyright 2012 Mark Gavillet

use strict;
use warnings;

use Koha::EDI::System::Koha;

=head1 NAME

Koha::EDI

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

sub new {
    my $class  = shift;
    my $system = shift;
    my $self   = {};
    $self->{system}     = 'koha';
    $self->{edi_system} = Koha::EDI::System::Koha->new();
    bless $self, $class;
    return $self;
}


sub retrieve_quotes {
    my $self                = shift;
    my @vendor_ftp_accounts = $self->{edi_system}->retrieve_vendor_ftp_accounts;
    my @downloaded_quotes =
      $self->{edi_system}->download_messages( \@vendor_ftp_accounts, 'QUOTE' );

    #    my $processed_quotes =
    $self->{edi_system}->process_quotes( \@downloaded_quotes );
    return;
}

sub retrieve_invoices {
    my $self                = shift;
    my @vendor_ftp_accounts = $self->{edi_system}->retrieve_vendor_ftp_accounts;
    my @downloaded_invoices = $self->{edi_system}
      ->download_messages( \@vendor_ftp_accounts, 'INVOICE' );

    #    my $processed_invoices =
    $self->{edi_system}->process_invoices( \@downloaded_invoices );
    return;
}

sub send_orders {
    my ( $self, $order_id, $ean ) = @_;
    my $orders = $self->{edi_system}->retrieve_orders($order_id);
    my $order_details =
      $self->{edi_system}->retrieve_order_details( $orders, $ean );
    foreach my $order ( @{$order_details} ) {

        #        my $module = $order->{module};
        #        require "Koha/EDI/Vendor/$module.pm";
        #        $module = "Koha::EDI::Vendor::$module";
        #        import $module;
        my $module        = 'Koha::EDI::Vendor::Default';
        my $vendor_module = $module->new();
        my $order_message = $vendor_module->create_order_message($order);
        my $order_file    = $self->{edi_system}
          ->create_order_file( $order_message, $order->{order_id} );
    }
    return;
}


1;
