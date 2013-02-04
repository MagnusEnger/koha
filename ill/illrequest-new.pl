#!/usr/bin/perl

# Copyright (c) 2013 Mark Gavillet & PTFS Europe
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
use C4::Auth;
use C4::Output;
use CGI;
use C4::Members;
use C4::Branch;
use C4::Letters;
use C4::Members::Attributes qw(GetBorrowerAttributes);
use C4::ILL;

use C4::Dates qw/format_date/;
my $query=new CGI;


my $borrowernumber = $query->param('borrowernumber');
#get borrower details
my $borrower = GetMember(borrowernumber => $borrowernumber);

my ($template, $loggedinuser, $cookie)
= get_template_and_user({template_name => "ill/illrequest-new.tt",
				query => $query,
				type => "intranet",
				authnotrequired => 0,
				flagsrequired => {borrowers => 1},
				debug => 1,
				});

my $borrower = GetMemberDetails( $borrowernumber );
$template->param( $borrower );
my ($picture, $dberror) = GetPatronImage($borrower->{'cardnumber'});
$template->param( picture => 1 ) if $picture;

my $requestnumber;
if ($query->param('requesttype'))
{
	$requestnumber=LogILLRequest($borrowernumber,$query);
}

my $illoptions;
if (!$query->param('illtype'))
{
	$illoptions=GetILLAuthValues('ILLTYPE');
}

my ($illlimit,$currentrequests)=ILLBorrowerRequests($borrowernumber);
my $remainingrequests=$illlimit-$currentrequests;

$template->param(CurrentRequests	=> $currentrequests);
$template->param(ILLLimit			=> $illlimit);
$template->param(RemainingRequests	=> $remainingrequests);
$template->param(RequestNumber 		=> $requestnumber);
$template->param(illtype			=> $query->param('illtype'));
$template->param(illoptions			=> $illoptions);
$template->param(borrowernumber		=> $borrowernumber);
$template->param( %{$borrower} );


output_html_with_http_headers $query, $cookie, $template->output;

