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
