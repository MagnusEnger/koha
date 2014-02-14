#!/usr/bin/perl

# Copyright 2011 Mark Gavillet & PTFS Europe Ltd
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
use Koha::EDI::Account;

my $input = CGI->new();

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'admin/edi-accounts.tmpl',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1 },
        debug           => ( $ENV{DEBUG} ) ? 1 : 0,
    }
);

my $op = $input->param('op');
$template->param( op => $op );

if ( $op eq 'delsubmit' ) {
    my $acct = Koha::EDI::Account->new( { id => $input->param('id') } );
    $acct->delete();
}

#FIXME  $inputparm path is not used in Create or Update
if ( $op eq 'addsubmit' ) {
    my $new_acct = Koha::EDI::Account->new(
        {
            description => $input->param('description'),
            host        => $input->param('host'),
            user        => $input->param('user'),
            pass        => $input->param('pass'),
            provider    => $input->param('provider'),
            path        => $input->param('path'),
            in_dir      => $input->param('in_dir'),
            san         => $input->param('san'),
        }
    );
    $new_acct->insert();
    $template->param( opaddsubmit => 1 );
}

if ( $op eq 'editsubmit' ) {
    my $acct = Koha::EDI::Account->new(
        {
            id          => $input->param('editid'),
            description => $input->param('description'),
            host        => $input->param('host'),
            user        => $input->param('user'),
            pass        => $input->param('pass'),
            provider    => $input->param('provider'),
            path        => $input->param('path'),
            in_dir      => $input->param('in_dir'),
            san         => $input->param('san'),
        }
    );
    $acct->update();
    $template->param( opeditsubmit => 1 );
}

my $ediaccounts = Koha::EDI::Account->get_all();
$template->param( ediaccounts => $ediaccounts );

output_html_with_http_headers( $input, $cookie, $template->output );
