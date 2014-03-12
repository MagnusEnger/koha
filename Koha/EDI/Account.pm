package Koha::EDI::Account;
use strict;
use warnings;
use C4::Context;

sub new {
    my ( $class, $arg_ref ) = @_;

    my $self = $arg_ref;

    bless $self, $class;
    return $self;
}

sub create {
    my ( $class, $arg_ref ) = @_;
    my $obj = $class->new($arg_ref);

    if ($obj) {
        $obj->insert();
        return $obj;
    }
    return;
}

sub retrieve {
    my $self = shift;
    if ( $self->{id} ) {
        my $dbh     = C4::Context->dbh;
        my $arr_ref = $dbh->selectall_arrayref(
            'select * from vendor_edi_accounts where id = ?',
            { slice => {} },
            $self->{id}
        );
        if ( @{$arr_ref} ) {
            $self = $arr_ref->[0];
            return 1;    # OK
        }
    }
    return;
}

sub insert {
    my $self = shift;
    if ( $self->{vendor_id} ) {
        my $dbh = C4::Context->dbh;
        my $sql = <<'END_INSSQL';
insert into vendor_edi_accounts
  (description, host, username, password, vendor_id, remote_directory, san)
  values (?,?,?,?,?,?,?)
END_INSSQL
        return $dbh->do(
            $sql, {},
            $self->{description}, $self->{host},
            $self->{user},        $self->{pass},
            $self->{vendor_id},   $self->{remote_directory},
            $self->{san}
        );
    }
    return;
}

sub del {
    my $self = shift;
    if ( $self->{id} ) {
        my $dbh = C4::Context->dbh;
        return $dbh->do( 'delete from vendor_edi_accounts where id=?',
            {}, $self->{id} );
    }
    return;
}

sub update {
    my $self = shift;
    if ( $self->{id} ) {
        my $dbh = C4::Context->dbh;
        my $sql = <<'END_UPDSQL';
update vendor_edi_accounts set description=?, host=?,
username=?, password=?, vendor_id=?, remote_directory=?, san=? where id=?
END_UPDSQL
        my $sth = $dbh->prepare($sql);
        $sth->execute(
            $self->{description}, $self->{host},
            $self->{user},        $self->{pass},
            $self->{vendor_id},   $self->{remote_directory},
            $self->{san},         $self->{id}
        );
    }
    return;
}

sub log_last_activity {
    my $self = shift;
    if ( $self->{id} ) {
        my $dbh = C4::Context->dbh;
        return $dbh->do(
'update vendor_edi_accounts set last_activity = curdate() where id = ?',
            {}, $self->{id}
        );
    }
    return;
}

sub download {
    my ( $self, $notice_type ) = @_;

    my @downloaded_files;
    my $ftp = Net::FTP->new(
        $self->{host},
        Timeout => 10,
        Passive => 1
      )
      or return _abort_download( undef, "Cannot connect to $self->{host}: $@" );
    $ftp->login( $self->{username}, $self->{password} )
      or _abort_download( $ftp, "Cannot login: $ftp->message()" );
    $ftp->cwd( $self->{remote_directory} )
      or _abort_download( $ftp, "Cannot change remote dir : $ftp->message()" );
    my $file_list = $ftp->ls()
      or _abort_download( $ftp, 'cannot get file list from server' );
    foreach my $filename ( @{$file_list} ) {
        if ( $self->is_file_new($filename) ) {

            #$ftp->get(__REMOTE_FILE__, __LOCAL_FILE__);
            push @downloaded_files, $filename;
        }
    }
    $ftp->quit;

    return @downloaded_files;
}

sub _abort_download {

    # log info if ftp open close it
    #returns undef i.e. an empty array
    return;
}

# getters & setters

sub id {
    my $self = shift;
    return $self->{id};
}

# Class methods

sub get_all {
    my $class = shift;
    my $dbh   = C4::Context->dbh;
    my $sql   = <<'ENDACCSQL';
        select vendor_edi_accounts.*,
        aqbooksellers.name as vendor
        from vendor_edi_accounts left join
        aqbooksellers on vendor_edi_accounts.vendor_id = aqbooksellers.id
        order by aqbooksellers.name asc
ENDACCSQL
    my $tuples = $dbh->selectall_arrayref( $sql, { Slice => {} } );
    my @accts = map { $class->new($_) } @{$tuples};
    return \@accts;
}

sub exist {
    my ( $class, $booksellerid ) = @_;
    my $dbh     = C4::Context->dbh;
    my $ary_ref = $dbh->selectcol_arrayref(
        'select count(*) from vendor_edi_accounts where vendor_id=?',
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

=head2 exist

Koha::EDI::Account->exist(booksellerid);

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
