#!/usr/bin/perl

# Copyright 2011,2014 Mark Gavillet & PTFS Europe Ltd
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
use C4::Bookseller qw( GetVendorList );

my $input = CGI->new();

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'admin/edi_accounts.tmpl',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { acquisition => 'edi_manage' },
    }
);

my $op = $input->param('op');
$op ||= 'display';

if ( $op eq 'acct_form' ) {
    show_account();
    $template->param( acct_form => 1 );
    my $vendors = GetVendorList();
    $template->param( vendors => $vendors );
}
elsif ( $op eq 'delete_confirm' ) {
    show_account();
    $template->param( delete_confirm => 1 );
}
else {
    if ( $op eq 'save' ) {

        # validate & display
        my $id     = $input->param('id');
        my $fields = {
            description => $input->param('description'),
            host        => $input->param('host'),
            user        => $input->param('username'),
            pass        => $input->param('password'),
            vendor_id   => $input->param('vendor_id'),
            directory   => $input->param('directory'),
            san         => $input->param('san'),
        };
        if ($id) {
            $fields->{id} = $id;
            my $acct = Koha::EDI::Account->new($fields);
            $acct->update();
        }
        else {    # new record
            my $new_acct = Koha::EDI::Account->new($fields);
            $new_acct->insert();
        }
    }
    elsif ( $op eq 'delete_confirmed' ) {

        my $acct = Koha::EDI::Account->new( { id => $input->param('id') } );
        $acct->del();
    }

    # we do a default dispaly after deletes and saves
    # as well as when thats all you want
    $template->param( display => 1 );
    my $ediaccounts = Koha::EDI::Account->get_all();
    $template->param( ediaccounts => $ediaccounts );
}

output_html_with_http_headers( $input, $cookie, $template->output );

sub get_account {
    my $id = shift;

    my $account = Koha::EDI::Account->new( { id => $id } );
    if ( $account->retrieve() ) {
        return $account;
    }

    # passing undef will default to add
    return;
}

sub show_account {
    my $acct_id = $input->param('id');
    if ($acct_id) {
        my $acc = get_account($acct_id);
        if ($acc) {
            $template->param( account => $acc );
        }
    }
    return;
}
