#!/usr/bin/perl
#
# c 2015 PTFS-Europe Ltd
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
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA
#

use Modern::Perl;
use CGI;
use C4::Auth;
use C4::Output;
use C4::Context;
use Koha::Database;
use C4::Members qw( GetMember );
use C4::Branch qw( GetBranchName );
use Koha::Till;

my $q = CGI->new();
my ( $template, $loggedinuser, $cookie, $user_flags ) = get_template_and_user(
    {
        template_name   => 'cm/pay.tt',
        query           => $q,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { cashmanage => q{*} },
    }
);

my $tillid = SessionTillId();
my $schema = Koha::Database->new()->schema();

my @payment_types = $schema->resultset('PaymentType')->search( { category => 'PaymentType', });

my @transcodes = $schema->resultset('CashTranscode')->search( undef, { order_by => { -asc => 'code', }});




## Placeholder we need a screen for accepting payments not borrower related
## e.g. sale of goods
### and recording such as a transaction

$template->param(
    branchname => $branchname,
    paymenttypes => \@paymenttypes,
    transcodes   => \@transcodes,
);

output_html_with_http_headers( $q, $cookie, $template->output );
