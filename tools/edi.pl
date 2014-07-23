#!/usr/bin/perl
#FIXME these does not belong in tools should integrate into acq

# Copyright 2011 Mark Gavillet & PTFS Europe Ltd
# Copyright 2014 PTFS Europe Ltd
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
use CGI;
use C4::Auth;
use C4::Output;
use Koha::Database;

my $input = CGI->new();

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'tools/edi.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { acquisition => 'edi_manage' },
    }
);

my $schema = Koha::Database->new()->schema();

# FIXME this is going to get very inefficient add params to seach
# instead of calling all [ use pager to get a Data::Page ]
my @msg_arr = $schema->resultset('EdifactMessage')->search(
    { deleted => 0 },
    {
        join => 'vendor',
    }
);

$template->param( messagelist =>  \@msg_arr );

output_html_with_http_headers( $input, $cookie, $template->output );
