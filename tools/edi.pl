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
use Koha::EDI::Message;

my $input = CGI->new();

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'tools/edi.tmpl',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1 },
        debug           => ( $ENV{DEBUG} ) ? 1 : 0,
    }
);


# FIXME this is going to get very inefficient
$template->param( messagelist => Koha::EDI::Message->get_all() );

output_html_with_http_headers( $input, $cookie, $template->output );
