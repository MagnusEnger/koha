#!/usr/bin/perl

# This file is part of Koha.
# Copyright 2013 PTFS-Europe and Mark Gavillet

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
require Exporter;
use CGI;
use C4::Auth;
use C4::Output;
use C4::Koha;
use C4::Branch;
use C4::Budgets;
use C4::Search;
use C4::Dates qw(format_date);
use C4::Members;
use C4::ILL;
use C4::Context;

my $input           = CGI->new;
my $request_type;
if (!$input->param('request_type'))
{
	$request_type='ALL';
}
else
{
	$request_type=$input->param('request_type');
}

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
        {
            template_name   => "ill/ill-requests.tt",
            query           => $input,
            type            => "intranet",
            flagsrequired   => { catalogue => 1 },
        }
    );

my $fullstatus=GetILLAuthValues('ILLSTATUS');
my $tmpfullstatus;

my $currentstatusloop = GetDistinctValues("illrequest.status");
my @allillrequests=GetAllILL($request_type);

$template->param( allillrequests => \@allillrequests);
$template->param( fullstatusloop => $fullstatus);
$template->param( currentstatusloop => $currentstatusloop);
$template->param( request_type => $request_type);
$template->param( new_status => C4::Context->preference("ILLNewRequestStatus"));

output_html_with_http_headers $input, $cookie, $template->output;
