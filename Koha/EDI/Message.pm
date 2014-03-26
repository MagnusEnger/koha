package Koha::EDI::Message;

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

sub new {
    my ( $class, $arg_ref ) = @_;
    my $self = $arg_ref;

    bless $self, $class;
    return $self;
}

# Class methods
#
#TBD return array as array of objects
sub get_all {
    my $class = shift;
    my $dbh   = C4::Context->dbh;
    my $sql   = <<'ENDMSGSQL';
    select edifact_messages.id, edifact_messages.message_type,
    edifact_messages.date_sent, edifact_messages.vendor_id,
    edifact_messages.status, edifact_messages.basketno,
    edifact_messages.invoiceid,
    edifact_messages.edi,
    edifact_messages.remote_file,
    aqinvoices.invoicenumber,
    aqbooksellers.name as providername
    from edifact_messages 
    left outer join aqbooksellers on edifact_messages.vendor_id = aqbooksellers.id
    left outer join aqinvoices on edifact_messages.invoiceid = aqinvoices.invoiceid
    order by edifact_messages.date_sent desc, edifact_messages.id desc
ENDMSGSQL
    return $dbh->selectall_arrayref( $sql, { Slice => {} } );
}

sub retrieve {
    my $self = shift;
    if ( $self->{id} ) {
        my $sql = <<'ENDSELSQL';
    select edifact_messages.message_type,
    edifact_messages.date_sent, edifact_messages.vendor_id,
    edifact_messages.status, edifact_messages.basketno,
    edifact_messages.invoiceid,
    edifact_messages.edi,
    edifact_messages.remote_file,
    aqinvoices.invoicenumber,
    aqbooksellers.name as providername
    from edifact_messages 
    left outer join aqbooksellers on edifact_messages.vendor_id = aqbooksellers.id
    left outer join aqinvoices on edifact_messages.invoiceid = aqinvoices.invoiceid
    where edifact_messages.id = ?
ENDSELSQL
        my $dbh = C4::Context->dbh;
        my $arr_ref =
          $dbh->selectall_arrayref( $sql, { Slice => {} }, $self->{id} );
        if ( @{$arr_ref} ) {
            for my $attribute ( keys %{ $arr_ref->[0] } ) {
                $self->{$attribute} = $arr_ref->[0]->{$attribute};
            }
            return 1;    # return success
        }
    }
    return;
}

sub insert {
    my ($self) = @_;
    my $sql = <<'ENDINSSQL';
insert into edifact_messages 
(message_type, date_sent, vendor_id, status, basketno, invoiceid, edi, remote_file)
values (?,?,?,?,?,?,?,?)
ENDINSSQL
    my $dbh = C4::Context->dbh;
    $dbh->do(
        $sql, {}, $self->{message_type},
        $self->{date_sent}, $self->{vendor_id}, $self->{status},
        $self->{basketno},  $self->{invoiceid}, $self->{edi},
        $self->{remote_file}
    );
    $self->{id} = $dbh->{mysql_insertid};
    return;
}

sub del {
    my $self = shift;
    if ( $self->{id} ) {
        my $dbh = C4::Context->dbh;
        return $dbh->do( 'delete from edifact_messages where id = ?',
            {}, $self->{id} );
    }
    return;
}

sub update {
    my ( $self, $arg_ref ) = @_;
    if ( $self->{id} ) {
        if ( exists $arg_ref->{message_type} ) {
            $self->{message_type} = $arg_ref->{message_type};
        }
        if ( exists $arg_ref->{edi} ) {
            $self->{edi} = $arg_ref->{edi};
        }
        if ( exists $arg_ref->{date_sent} ) {
            $self->{date_sent} = $arg_ref->{date_sent};
        }
        if ( exists $arg_ref->{vendor_id} ) {
            $self->{vendor_id} = $arg_ref->{vendor_id};
        }
        if ( exists $arg_ref->{status} ) {
            $self->{status} = $arg_ref->{status};
        }
        if ( exists $arg_ref->{basketno} ) {
            $self->{basketno} = $arg_ref->{basketno};
        }
        if ( exists $arg_ref->{invoiceid} ) {
            $self->{invoiceid} = $arg_ref->{invoiceid};
        }
        if ( exists $arg_ref->{remote_file} ) {
            $self->{remote_file} = $arg_ref->{remote_file};
        }
    }
    return;
}

sub save {
    my $self = shift;
    if ( $self->{id} ) {
        my $sql = <<'ENDUPDSQL';
update edifact_messages
set message_type = ?, date_sent = ?, vendor_id = ?, status = ?,
basketno = ? invoiceid = ?, edi = ?, remote_file = ?
where id = ?
ENDUPDSQL
        my $dbh = C4::Context->dbh;
        return $dbh->do(
            $sql, {},
            $self->{message_type}, $self->{date_sent},
            $self->{vendor_id},    $self->{status},
            $self->{basketno},     $self->{invoiceid},
            $self->{edi},          $self->{remote_file},
            $self->{id}
        );

    }
    return;
}

1;
