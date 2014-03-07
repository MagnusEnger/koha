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
    edifact_messages.date_sent, edifact_messages.provider,
    edifact_messages.status, edifact_messages.basketno,
    aqbooksellers.name as providername
    from edifact_messages 
    left outer join aqbooksellers on edifact_messages.provider = aqbooksellers.id
    order by edifact_messages.date_sent desc, edifact_messages.id desc
ENDMSGSQL

    # edifact_messages.invoicenumber from edifact_messages
    return $dbh->selectall_arrayref( $sql, { Slice => {} } );
}
1;
