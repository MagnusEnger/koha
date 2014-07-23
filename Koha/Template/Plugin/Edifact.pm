package Koha::Template::Plugin::Edifact;

# Copyright PTFS Europe 201ub

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

use Modern::Perl;

use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );
use CGI qw( escapeHTML);

sub filter {
    my ( $self, $text ) = @_;
    if ( !$text ) {
        return q{};
    }
    my $re = qr{
(?>    # dont backtrack into this group
    \?.      # either the escape character
            # followed by any other character
     |      # or
     [^'?]   # a character that is neither escape
             # nor split
             )+
}x;
    my $filtered_text = q{};
    while ( $text =~ /($re)/g ) {
        my $segment = escapeHTML($1);
        $filtered_text .= "<p>$segment`</p>";
    }
    return $filtered_text;

}
1;
