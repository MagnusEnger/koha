package C4::ILL;

# Copyright 2012 Mark Gavillet & PTFS Europe
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
use C4::Context;
use C4::Dates qw(format_date_in_iso format_date);
use Digest::MD5 qw(md5_base64);
use Date::Calc qw/Today Add_Delta_YM check_date Date_to_Days/;
use C4::Log; # logaction
use C4::Overdues;
use C4::Reserves;
use C4::Accounts;
use C4::Biblio;
use C4::Letters;
use C4::SQLHelper qw(InsertInTable UpdateInTable SearchInTable);
use C4::Members::Attributes qw(SearchIdMatchingAttribute);
use C4::NewsChannels; #get slip news
use DateTime;
use DateTime::Format::DateParse;
use Koha::DateUtils;
use C4::Koha;
use C4::Members;
use Mail::Sendmail;
use C4::Branch;

our ($VERSION,@ISA,@EXPORT,@EXPORT_OK,$debug);

BEGIN {
    $VERSION = 3.08.01.002;
    $debug = $ENV{DEBUG} || 0;
    require Exporter;
    @ISA = qw(Exporter);
    #Get data
    push @EXPORT, qw(
        &GetMyILL
        &FormatILLReference
        &GetILLAuthValues
        &ILLBorrowerRequests
        &LogILLRequest
        &GetAllILL
        &GetILLRequest
        &DeleteILLRequest
        &UpdateILLRequest
    );
}

sub UpdateILLRequest
{
	my ($requestid, $biblionumber, $status, $title, $author, $journal_title, $publisher, $issn, $year, $season, $month, $day,
		$volume, $part, $issue, $special_issue, $article_title, $author_names, $pages, $notes, $conference_title,
		$conference_author, $conference_venue, $conference_date, $isbn, $edition, $chapter_title, $composer, $ismn,
		$university, $dissertation, $scale, $shelfmark) =@_;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
    $sth = $dbh->prepare("update illrequest set biblionumber=?, status=?, title=?, author_editor=?, journal_title=?, publisher=?, issn=?,
    						year=?, season=?, month=?, day=?, volume=?, part=?, issue=?, special_issue=?, article_title=?, author_names=?, 
    						pages=?, notes=?, conference_title=?, conference_author=?, conference_venue=?, conference_date=?, isbn=?, 
    						edition=?, chapter_title=?, composer=?, ismn=?, university=?, dissertation=?, scale=?, shelfmark=? where requestid=?");
    $sth->execute($biblionumber, $status, $title, $author, $journal_title, $publisher, $issn, $year, $season, $month, $day,
		$volume, $part, $issue, $special_issue, $article_title, $author_names, $pages, $notes, $conference_title,
		$conference_author, $conference_venue, $conference_date, $isbn, $edition, $chapter_title, $composer, $ismn,
		$university, $dissertation, $scale, $shelfmark, $requestid);
}

sub DeleteILLRequest
{
	my $requestid=shift;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
    $sth = $dbh->prepare("delete from illrequest where requestid=?");
    $sth->execute($requestid);
}

sub GetILLRequest
{
	my $requestid=shift;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
    if ($requestid)
    {
        $sth = $dbh->prepare("select * from illrequest where requestid=?");
        $sth->execute($requestid);
        my $request = $sth->fetchrow_hashref();
        return $request;
    }
    else
    {
	    return;
    }
}

sub GetMyILL {
    my ($borrowernumber) = shift;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
    my $tmp_request;
    my @formatted_requests;
    my $ref;
    my $opac_status;
    my $ill_prefix = C4::Context->preference("ILLRequestPrefix");
    if ($borrowernumber) {
        $sth = $dbh->prepare("select * from illrequest where borrowernumber=? order by date_placed asc");
        $sth->execute($borrowernumber);
        my $requests = $sth->fetchall_arrayref({});
        if ($requests)
        {
	        foreach my $req (@$requests)
	        {
	        	$ref=FormatILLReference($req);
	        	my $status=GetAuthorisedValues('ILLSTATUS',$req->{status},'opac') if $req->{status};
		    	undef $opac_status;
		    	for my $stat (@$status)
		    	{
		    		if ($req->{status} eq $stat->{authorised_value})
		    		{
			    		$opac_status=$stat->{'lib'};
			    	}
		    	}
		        $tmp_request={
			        ref				=>	$ref,
			        requestnumber	=>	$ill_prefix.$req->{requestnumber},
			        requestid		=>	$req->{requestid},
			        biblionumber	=>	$req->{biblionumber},
			        date_placed		=>	$req->{date_placed},
			        request_type	=>	$req->{request_type},
			        status			=>	$opac_status,
		        };
		        push (@formatted_requests,$tmp_request);
	        }
	    }
	    return @formatted_requests;
    }
    else
    {
    	return;
    }
}

sub GetAllILL
{
	my $return_type=shift;
    my $dbh = C4::Context->dbh;
    my $query;
    my $sth;
    my $tmp_request;
    my @formatted_requests;
    my $ref;
    my $ill_prefix = C4::Context->preference("ILLRequestPrefix");
    if ($return_type eq "ALL")
    {
    	$sth = $dbh->prepare("select * from illrequest order by date_placed asc");
    	$sth->execute();
    }
    elsif ($return_type eq "NEW")
    {
    	my $newstatus=C4::Context->preference("ILLNewRequestStatus");
    	$sth = $dbh->prepare("select * from illrequest where status=? order by date_placed asc");
    	$sth->execute($newstatus);
    }
    elsif ($return_type eq "COMPLETED")
    {
    	$sth = $dbh->prepare("select * from illrequest where completed_date is not null order by date_placed asc");
    	$sth->execute();
    }
    elsif ($return_type eq "OPENNOTNEW")
    {
    	my $newstatus=C4::Context->preference("ILLNewRequestStatus");
    	$sth = $dbh->prepare("select * from illrequest where completed_date is null and status<>? order by date_placed asc");
    	$sth->execute($newstatus);
    }
    my $requests = $sth->fetchall_arrayref({});
    if ($requests)
	{
	    foreach my $req (@$requests)
	    {
	    	$ref=FormatILLReference($req);
	    	my $borrower = GetMemberDetails( $req->{borrowernumber} );
	    	my $opac_status;
	    	my $request_type_label;
	    	my $status=GetAuthorisedValues('ILLSTATUS',$req->{status},'opac') if $req->{status};
	    	undef $opac_status;
	    	for my $stat (@$status)
	    	{
	    		if ($req->{status} eq $stat->{authorised_value})
	    		{
		    		$opac_status=$stat->{'lib'};
		    	}
	    	}
	    	my $req_labels=GetAuthorisedValues('ILLTYPE',$req->{request_type},'opac') if $req->{request_type};
	    	undef $request_type_label;
	    	for my $req_label (@$req_labels)
	    	{
	    		if ($req->{request_type} eq $req_label->{authorised_value})
	    		{
		    		$request_type_label=$req_label->{'lib'};
		    	}
	    	}
		    $tmp_request={
		    	ref					=>	$ref,
			    requestnumber		=>	$ill_prefix.$req->{requestnumber},
			    requestid			=>	$req->{requestid},
			    biblionumber		=>	$req->{biblionumber},
			    date_placed			=>	$req->{date_placed},
			    request_type		=>	$req->{request_type},
			    status				=>	$opac_status,
			    borrowernumber		=>	$req->{borrowernumber},
			    status_code			=>	$req->{status},
			    completed_date		=>	$req->{completed_date},
			    request_type_label	=>	$request_type_label,
			    branch_code			=>	$req->{orig_branch},
			    branchname			=>	GetBranchName($req->{orig_branch}),
			    borrowername		=>	$borrower->{showname}." ".$borrower->{surname},
		    };
		    push (@formatted_requests,$tmp_request);
	    }
	    return @formatted_requests;
	}
	else
	{
		return;
	}
}

sub LogILLRequest
{
	my ($borrowernumber,$query)=@_;
	my $borrower = GetMemberDetails( $borrowernumber );
	my $branch = $borrower->{'branchcode'};
	my $dbh = C4::Context->dbh;
	my $sth = $dbh->prepare('select requestnumber from illrequest order by requestnumber desc limit 1');
	$sth->execute();
	my ($reqno) = $sth->fetchrow;
	$reqno++;
	
	if ($query->param('requesttype') eq 'ILLBOOK')
	{
		my $sth = $dbh->prepare('insert into illrequest (requestnumber, borrowernumber, status, date_placed, request_type, orig_branch, service_branch, title, author_editor, publisher, isbn, edition, year, chapter_title, author_names, pages, notes) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
		$sth->execute($reqno, $borrowernumber, C4::Context->preference("ILLNewRequestStatus"), DateTime->today->format_cldr('YYYY-MM-dd'), $query->param('requesttype'), $branch, $branch, $query->param('title'), $query->param('author'), $query->param('publisher'), $query->param('isbn'), $query->param('edition'), $query->param('year'), $query->param('chapter_title'), $query->param('author_names'), $query->param('pages'), $query->param('notes'));
		my $submitted_request=C4::Context->preference("ILLRequestPrefix").$reqno;
		my $notify=C4::Context->preference("ILLEmailNotify");
		if ($notify==1)
		{
			SendILLNotification($borrowernumber, $submitted_request, $borrower->{'email'});
		}
		return $submitted_request;
	}
	if ($query->param('requesttype') eq 'ILLJOURNAL')
	{
		my $sth = $dbh->prepare('insert into illrequest (requestnumber, borrowernumber, status, date_placed, request_type, orig_branch, service_branch, journal_title, publisher, issn, year, season, month, day, part, issue, special_issue, article_title, author_names, pages, notes, conference_title, conference_author, conference_venue, conference_date, isbn) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
		$sth->execute($reqno, $borrowernumber, C4::Context->preference("ILLNewRequestStatus"), DateTime->today->format_cldr('YYYY-MM-dd'), $query->param('requesttype'), $branch, $branch, $query->param('title'), $query->param('publisher'), $query->param('issn'), $query->param('year'), $query->param('season'), $query->param('month'), $query->param('day'), $query->param('part'), $query->param('issue'), $query->param('special_issue'), $query->param('article_title'), $query->param('author_names'), $query->param('pages'), $query->param('notes'), $query->param('conference_title'), $query->param('conference_author'), $query->param('conference_venue'), $query->param('conference_date'), $query->param('isbn'));
		my $submitted_request=C4::Context->preference("ILLRequestPrefix").$reqno;
		my $notify=C4::Context->preference("ILLEmailNotify");
		if ($notify==1)
		{
			SendILLNotification($borrowernumber, $submitted_request, $borrower->{'email'});
		}

		return $submitted_request;
	}
	if ($query->param('requesttype') eq 'ILLTHESIS')
	{
		my $sth = $dbh->prepare('insert into illrequest (requestnumber, borrowernumber, status, date_placed, request_type, orig_branch, service_branch, title, author_editor, university, dissertation, year, chapter_title, pages, notes) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
		$sth->execute($reqno, $borrowernumber, C4::Context->preference("ILLNewRequestStatus"), DateTime->today->format_cldr('YYYY-MM-dd'), $query->param('requesttype'), $branch, $branch, $query->param('title'), $query->param('author'), $query->param('university'), $query->param('dissertation'), $query->param('year'), $query->param('chapter_title'), $query->param('pages'), $query->param('notes'));
		my $submitted_request=C4::Context->preference("ILLRequestPrefix").$reqno;
		my $notify=C4::Context->preference("ILLEmailNotify");
		if ($notify==1)
		{
			SendILLNotification($borrowernumber, $submitted_request, $borrower->{'email'});
		}

		return $submitted_request;
	}
	if ($query->param('requesttype') eq 'ILLOTHER')
	{
		my $sth = $dbh->prepare('insert into illrequest (requestnumber, borrowernumber, status, date_placed, request_type, orig_branch, service_branch, title, author_editor, composer, ismn, isbn, edition, year, scale, notes) values (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
		$sth->execute($reqno, $borrowernumber, C4::Context->preference("ILLNewRequestStatus"), DateTime->today->format_cldr('YYYY-MM-dd'), $query->param('requesttype'), $branch, $branch, $query->param('title'), $query->param('author'), $query->param('composer'), $query->param('ismn'), $query->param('isbn'), $query->param('edition'), $query->param('year'), $query->param('scale'), $query->param('notes'));
		my $submitted_request=C4::Context->preference("ILLRequestPrefix").$reqno;
		my $notify=C4::Context->preference("ILLEmailNotify");
		if ($notify==1)
		{
			SendILLNotification($borrowernumber, $submitted_request, $borrower->{'email'});
		}

		return $submitted_request;
	}
}

sub SendILLNotification
{
	my ($borrowernumber, $submitted_request, $borrower_email)=@_;
	my %mail=
	(
		To		=>	$borrower_email,
		From	=>	C4::Context->preference('KohaAdminEmailAddress'),
		Subject	=>	'Inter-Library Loan Request '.$submitted_request,
		Message	=>	'Your Inter-Library Loan request was successfully placed. Your reference number is '.$submitted_request
	);
	sendmail(%mail);
}

sub GetILLAuthValues {
	my $authval_type=shift;
	my $dbh = C4::Context->dbh;
	my $sth = $dbh->prepare('select authorised_value,lib,id from authorised_values where category=? order by lib asc');
	$sth->execute($authval_type);
	my $tmp_authval;
	my @ill_authvalues;
	my $authvals = $sth->fetchall_arrayref({});
	if ($authvals)
	{
		foreach my $authval (@$authvals)
		{
			$tmp_authval={
				authorised_value	=>	$authval->{authorised_value},
				lib					=>	$authval->{lib},
				id					=>	$authval->{id},
			};
			push (@ill_authvalues,$tmp_authval);
		}
	}
	#return @ill_authvalues;
	return $authvals;
}

sub FormatILLReference($req)
{
	my $req=shift;
	my $ref;
	if ($req->{request_type} eq 'ILLBOOK')
	{
        if ($req->{chapter_title} ne '')
        {
	        $ref=$req->{author_names}.", ".$req->{chapter_title};
	        if ($req->{isbn} ne '')
	        {
		        $ref.=" (".$req->{isbn}.")";
	        }
	        $ref.="<br />in ".$req->{title};
        }
        else
        {
	        $ref=$req->{title};
	        if ($req->{isbn} ne '')
	        {
		        $ref.=" (".$req->{isbn}.")";
	        }
	        $ref.="<br />";
	        $ref.=$req->{author_editor};
        }
	}
	elsif ($req->{request_type} eq 'ILLJOURNAL')
	{
    	if ($req->{article_title} ne '')
    	{
        	$ref=$req->{author_names}.", ".$req->{article_title};
        	$ref.="<br />in ".$req->{journal_title};
	        if ($req->{issue} ne '')
	        {
		        $ref.=", Issue ".$req->{issue};
	        }
	        if ($req->{volume} ne '')
	        {
		        $ref.=", Vol. ".$req->{volume};
	        }
	        if ($req->{pages} ne '')
	        {
		        $ref.="<br />Pages ".$req->{pages};
	        }
    	}
    	else
    	{
	        $ref=$req->{journal_title};
	        if ($req->{issue} ne '')
	        {
		        $ref.=", Issue ".$req->{issue};
	        }
	        if ($req->{volume} ne '')
	        {
		        $ref.=", Vol. ".$req->{volume};
	        }
        }
	}
	elsif ($req->{request_type} eq 'ILLTHESIS')
	{
		if ($req->{chapter_title} ne '')
		{
			$ref=$req->{author_editor}.", ".$req->{chapter_title}."<br />in ".$req->{title}." - ".$req->{university}.", ".$req->{dissertation};
		}
		else
		{
    		$ref=$req->{title}.", ".$req->{author_editor}." - ".$req->{university}.", ".$req->{dissertation};
    	}
	}
	elsif ($req->{request_type} eq 'ILLOTHER')
	{
    	$ref=$req->{title};
    	if ($req->{author_editor})
    	{
	    	$ref.=", ".$req->{author_editor};
    	}
    	if ($req->{composer})
    	{
	    	$ref.=", ".$req->{composer};
    	}
	}
	return $ref;
}

sub ILLBorrowerRequests
{
	my $borrowernumber=shift;
	my $dbh = C4::Context->dbh;
	my $sth = $dbh->prepare('select categories.illlimit from categories inner join borrowers on borrowers.categorycode=categories.categorycode where borrowers.borrowernumber=?');
	$sth->execute($borrowernumber);
	my ($illlimit) = $sth->fetchrow;
	my $sth = $dbh->prepare('select count(illrequest.requestid) as illrequests from illrequest where illrequest.borrowernumber=? and illrequest.completed_date IS NULL');
	$sth->execute($borrowernumber);
	my ($currentrequests) = $sth->fetchrow;
	return ($illlimit,$currentrequests);
}

1;