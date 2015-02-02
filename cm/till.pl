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
use List::Util qw(sum);

my $q = CGI->new();
my ( $template, $loggedinuser, $cookie, $user_flags ) = get_template_and_user(
    {
        template_name   => 'cm/till.tt',
        query           => $q,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { cashmanage => q{*} },
    }
);

my $user       = GetMember( 'borrowernumber' => $loggedinuser );
my $branchname = GetBranchName( $user->{branchcode} );

# here be tigers
#
my $schema = Koha::Database->new()->schema;

my $till = get_till($schema, $q);

my @transactions = $schema->resultset('CashTransaction')->search(
    { till => $till->tillid() },
    { order_by => 'created' }
)->all();


my $total_paid_in = sum grep { $_->amt if $_->amt > 0} @transactions;
my $total_paid_out = sum grep { $_->amt if $_->amt < 0} @transactions;



$template->param(
    branchname => $branchname,
    till       => $till,
    transactions => \@transactions,
    total_in => $total_paid_in,
    total_out => $total_paid_out,
);

output_html_with_http_headers( $q, $cookie, $template->output );

sub get_till {
    my ($schema, $cgi_query) = @_;
    

    my $id = $cgi_query->param('till_id');
    $id ||= SessionTillId();

    if ( $id ) {
        return $schema->resultset('CashTill')->find($id);
    }
    # use name
    my $name = $cgi_query->param('till_name');
    $name ||= 'DEFAULT';
    my $rs = $schema->resultset('CashTill')->search( { description => $name });
    return $rs->single;
}
