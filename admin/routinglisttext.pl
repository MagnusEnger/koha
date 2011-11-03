#!/usr/bin/env perl

# Copyright 2011 PTFS-Europe Ltd.
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
use 5.10.1;

use CGI;

use C4::Auth qw(get_template_and_user);
use C4::Output qw(output_html_with_http_headers);
use C4::RoutingSlip::Copyright;


my $q = CGI->new();
my $op = $q->param('op') || q{};

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => 'admin/routinglisttext.tmpl',
        query           => $q,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { parameters => 1},
        debug           => 1,
    }
);

if ( $op eq 'add') {
}
elsif ($op eq 'edit') {
}
else {
    my $list_arrayref = C4::RoutingSlip::Copyright->get_all();

    $template->param( 'message_list' => $list_arrayref );
    my $c = @{$list_arrayref};
    warn "Passing $c entries";
}

output_html_with_http_headers $q, $cookie, $template->output;
