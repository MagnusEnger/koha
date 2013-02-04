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
use C4::Context;

use C4::Dates qw/format_date/;
my $input=new CGI;


my $requestid = $input->param('requestid');
my $op = $input->param('op');

my ($template, $loggedinuser, $cookie)
= get_template_and_user({template_name => "ill/illrequest-details.tt",
				query => $input,
				type => "intranet",
				authnotrequired => 0,
				flagsrequired => {borrowers => 1},
				debug => 1,
				});

if ($op eq 'delconfirmed')
{
	DeleteILLRequest($requestid);
	$template->param(deleted=>1);
}

if ($op eq 'request_book' || $op eq 'request_thesis' || $op eq 'request_journal' || $op eq 'request_other')
{
	my $biblionumber;
	my $status;
	my $title;
	my $author;
	my $journal_title;
	my $publisher;
	my $issn;
	my $year;
	my $season;
	my $month;
	my $day;
	my $volume;
	my $part;
	my $issue;
	my $special_issue;
	my $article_title;
	my $author_names;
	my $pages;
	my $notes;
	my $conference_title;
	my $conference_author;
	my $conference_venue;
	my $conference_date;
	my $isbn;
	my $edition;
	my $chapter_title;
	my $composer;
	my $ismn;
	my $university;
	my $dissertation;
	my $scale;
	my $shelfmark;
	
	$biblionumber		= $input->param('biblionumber');
	$status				= $input->param('status');
	$title				= $input->param('title');
	$author				= $input->param('author');
	$journal_title		= $input->param('journal_title');
	$publisher			= $input->param('publisher');
	$issn				= $input->param('issn');
	$year				= $input->param('year');
	$season				= $input->param('season');
	$month				= $input->param('month');
	$day				= $input->param('day');
	$volume				= $input->param('volume');
	$part				= $input->param('part');
	$issue				= $input->param('issue');
	$special_issue		= $input->param('special_issue');
	$article_title		= $input->param('article_title');
	$author_names		= $input->param('author_names');
	$pages				= $input->param('pages');
	$notes				= $input->param('notes');
	$conference_title	= $input->param('conference_title');
	$conference_author	= $input->param('conference_author');
	$conference_venue	= $input->param('conference_venue');
	$conference_date	= $input->param('conference_date');
	$isbn				= $input->param('isbn');
	$edition			= $input->param('edition');
	$chapter_title		= $input->param('chapter_title');
	$composer			= $input->param('composer');
	$ismn				= $input->param('ismn');
	$university			= $input->param('university');
	$dissertation		= $input->param('dissertation');
	$scale				= $input->param('scale');
	$shelfmark			= $input->param('shelfmark');
	
	UpdateILLRequest(	$requestid,
						$biblionumber,
						$status,
						$title,
						$author,
						$journal_title,
						$publisher,
						$issn,
						$year,
						$season,
						$month,
						$day,
						$volume,
						$part,
						$issue,
						$special_issue,
						$article_title,
						$author_names,
						$pages,
						$notes,
						$conference_title,
						$conference_author,
						$conference_venue,
						$conference_date,
						$isbn,
						$edition,
						$chapter_title,
						$composer,
						$ismn,
						$university,
						$dissertation,
						$scale,
						$shelfmark,
						);
	$template->param(updated=>1);
}

my $illrequest=GetILLRequest($requestid);

my $illstatuses=GetILLAuthValues('ILLSTATUS');

my $ill_prefix = C4::Context->preference("ILLRequestPrefix");

my $borrower = GetMemberDetails( $illrequest->{'borrowernumber'});

$template->param(
			ILLRequest 			=> $illrequest,
			ill			 		=> 1,
			illstatuses			=> $illstatuses,
			ill_prefix			=> $ill_prefix,
			borrowername		=> $borrower->{showname}." ".$borrower->{surname},
			op					=> $op,
);
output_html_with_http_headers $input, $cookie, $template->output;

