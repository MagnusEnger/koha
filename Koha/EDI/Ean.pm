package Koha::EDI::Ean;
use strict;
use warnings;
use C4::Context;
use C4::Branch qw( GetBranchName );

sub new {
    my ( $class, $arg_ref ) = @_;

    my $self = $arg_ref;
    if ( !$self->{ean} || !$self->{branchcode} ) {
        return;
    }

    bless $self, $class;
    return $self;
}

sub create {
    my ( $class, $arg_ref ) = @_;
    my $obj = $class->new($arg_ref);

    # new + insert
    if ($obj) {
        $obj->insert();
        return $obj;
    }
    return;
}

sub insert {
    my $self = shift;
    my $dbh  = C4::Context->dbh;
    my $rv =
      $dbh->do( 'insert into edifact_ean ( branchcode, ean) values ( ?,? )',
        {}, $self->{branchcode}, $self->{ean} );

    # if $rv != 1 error
    return ( $rv == 1 );
}

sub change {
    my ( $self, $newval ) = @_;
    my $dbh = C4::Context->dbh;
    my $old = $self;
    if ( $newval->{branchcode} ) {
        $self->{branchcode} = $newval->{branchcode};
    }
    if ( $newval->{ean} ) {
        $self->{ean} = $newval->{ean};
    }
    return $dbh->do(
'update edifact_ean set branchcode=?, ean=? where branchcode=? and ean=?',
        {},
        $self->{branchcode},
        $self->{ean},
        $old->{branchcode},
        $old->{ean}
    );

}

sub del {
    my $self = shift;
    my $dbh  = C4::Context->dbh;
    return $dbh->do( 'delete from edifact_ean where branchcode=? and ean=?',
        {}, $self->{branchcode}, $self->{ean} );
}

sub ean {
    my $self = shift;
    return $self->{ean};
}

sub branchcode {
    my $self = shift;
    return $self->{branchcode};
}

sub branchname {
    my $self = shift;
    if ( !exists $self->{branchname} ) {
        $self->{branchname} = GetBranchName( $self->{branchcode} );
    }
    return $self->{branchname};
}

sub all {
    my $dbh = C4::Context->dbh;
    my $sql = <<'ENDSEL';
select branches.branchname, edifact_ean.ean, edifact_ean.branchcode from
 branches inner join edifact_ean on edifact_ean.branchcode=branches.branchcode
 order by branches.branchname asc'
ENDSEL
    my $tuples = $dbh->selectall_arrayref( $sql, { Slice => {} } );
    my $eans = map { Koha::EDI::Ean->new($_); } @{$tuples};
    return $eans;
}

1;
__END__

=head1 NAME

Koha::EDI::Ean - Ean object

=head1 SYNOPSIS

use Koha::EDI::Ean;

=head1 DESCRIPTION

This class handles accounts with vendors with whom the system
can order electronically using Edifact

=head1 METHODS

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
