package Koha::EDI::Account;


sub new {
    my ($class, $arg_ref) = @_;

    my $self = $arg_ref;

    bless $self, $class;
    return $self;
}

sub create {
    # new + insert
}

sub insert {
    my $self = shift;
    # insert in databasej:
}

# Class methods

sub exists {
    my ($class, $booksellerid) = @_;
    my $dbh          = C4::Context->dbh;
    my $ary_ref      = $dbh->selectcol_arrayref(
        'select count(*) from vendor_edi_accounts where provider=?',
        {}, $booksellerid );
    if ( $ary_ref->[0] ) {
        return 1;
    }
    else {
        return 0;
    }
}

1;
__END__

=head1 NAME

Koha::EDI::Account - Vendor accounts for electronic ordering

=head1 SYNOPSIS

use Koha::EDI::Account;

=head1 DESCRIPTION

This class handles accounts with vendors with whom the system
can order electronically using Edifact

=head1 METHODS

=head2 exists

Koha::EDI::Account->exists(booksellerid);

Class method - passed a booksellerid returns 1 if account(s)
exist otherwise returns zero

=head1 DIAGNOSTICS

=head1 DEPENDENCIES

=head1 BUGS AND LIMITATIONS

=head1 AUTHOR

Colin Campbell <colin.campbell@ptfs-europe.com>

=head1 LICENCE AND COPYRIGHT

Copyright 2014 PTFS-Europe Ltd

This file is part of Koha.

Koha is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

Koha is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Koha; if not, see <http://www.gnu.org/licenses>.
