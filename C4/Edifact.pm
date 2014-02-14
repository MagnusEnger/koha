package C4::Edifact;

# Copyright 2012 Mark Gavillet
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;
use C4::Context;
use C4::Acquisition;
use Net::FTP;
use Business::Edifact::Interchange;
use C4::Biblio;
use C4::Items;
use Business::ISBN;
use parent qw(Exporter);

our $VERSION   = 0.02;
our @EXPORT_OK = qw(
  GetVendorList
  DeleteEDIDetails
  CreateEDIDetails
  UpdateEDIDetails
  GetEDIAccounts
  GetEDIAccountDetails
  GetEDIfactMessageList
);

=head1 NAME

C4::Edifact - Perl Module containing functions for Vendor EDI accounts and EDIfact messages

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

use C4::Edifact;

=head1 DESCRIPTION

This module contains routines for managing EDI account details for vendors

=head2 GetVendorList

Returns a list of vendors from aqbooksellers to populate drop down select menu

=cut

sub GetVendorList {
    my $dbh = C4::Context->dbh;
    my $sth;
    $sth =
      $dbh->prepare('select id, name from aqbooksellers order by name asc');
    $sth->execute();
    my $vendorlist = $sth->fetchall_arrayref( {} );
    return $vendorlist;
}

=head2 DeleteEDIDetails

Remove a vendor's FTP account

=cut

sub DeleteEDIDetails {
    my $id  = shift;
    my $dbh = C4::Context->dbh;
    my $sth;
    if ($id) {
        $sth = $dbh->prepare('delete from vendor_edi_accounts where id=?');
        $sth->execute($id);
    }
    return;
}

=head2 CreateEDIDetails

Inserts a new EDI vendor FTP account

=cut

sub CreateEDIDetails {
    my ($arg_ref) = @_;
    if ( $arg_ref->{provider} ) {
        my $dbh = C4::Context->dbh;
        my $sql = <<'END_INSSQL';
insert into vendor_edi_accounts
  (description, host, username, password, provider, in_dir, san)
  values (?,?,?,?,?,?,?)
END_INSSQL
        my $sth = $dbh->prepare($sql);
        $sth->execute(
            $arg_ref->{description}, $arg_ref->{host},
            $arg_ref->{user},        $arg_ref->{pass},
            $arg_ref->{provider},    $arg_ref->{in_dir},
            $arg_ref->{san}
        );
    }
    return;
}

=head2 UpdateEDIDetails

Update a vendor's FTP account

=cut

sub UpdateEDIDetails {
    my ($arg_ref) = @_;
    if ( $arg_ref->{editid} ) {
        my $dbh = C4::Context->dbh;
        my $sql = <<'END_UPDSQL';
update vendor_edi_accounts set description=?, host=?,
username=?, password=?, provider=?, in_dir=?, san=? where id=?
END_UPDSQL
        my $sth = $dbh->prepare($sql);
        $sth->execute(
            $arg_ref->{description}, $arg_ref->{host},
            $arg_ref->{user},        $arg_ref->{pass},
            $arg_ref->{provider},    $arg_ref->{in_dir},
            $arg_ref->{san},         $arg_ref->{editid}
        );
    }
    return;
}

=head2 GetEDIAccounts

Returns all vendor FTP accounts

=cut

sub GetEDIAccounts {
    my $dbh = C4::Context->dbh;
    my $sql = <<'ENDACCSQL';
        select vendor_edi_accounts.id, aqbooksellers.id as providerid,
        aqbooksellers.name as vendor, vendor_edi_accounts.description,
        vendor_edi_accounts.last_activity from vendor_edi_accounts inner join
        aqbooksellers on vendor_edi_accounts.provider = aqbooksellers.id
        order by aqbooksellers.name asc
ENDACCSQL
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my $ediaccounts = $sth->fetchall_arrayref( {} );
    return $ediaccounts;
}

=head2 GetEDIAccountDetails

Returns FTP account details for a given vendor

=cut

sub GetEDIAccountDetails {
    my $id  = shift;
    my $dbh = C4::Context->dbh;
    my $sth;
    if ($id) {
        $sth = $dbh->prepare('select * from vendor_edi_accounts where id=?');
        $sth->execute($id);
        my $edi_details = $sth->fetchrow_hashref;
        return $edi_details;
    }
    return;
}

=head2 GetEDIfactMessageList

Returns a list of edifact_messages that have been processed, including the type (quote/order) and status

=cut

sub GetEDIfactMessageList {
    my $sql = <<'ENDMSGSQL';
    select edifact_messages.key, edifact_messages.message_type,
    DATE_FORMAT(edifact_messages.date_sent,"%d/%m/%Y") as date_sent,
    aqbooksellers.id as providerid, aqbooksellers.name as providername,
    edifact_messages.status, edifact_messages.basketno,
   :w
 edifact_messages.invoicenumber from edifact_messages
    inner join aqbooksellers on edifact_messages.provider = aqbooksellers.id
    order by edifact_messages.date_sent desc, edifact_messages.key desc
ENDMSGSQL
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare($sql);
    $sth->execute();
    my $messagelist = $sth->fetchall_arrayref( {} );
    return $messagelist;
}


1;

__END__

=head1 AUTHOR

Mark Gavillet

=cut
