package Koha::EDI::Account;
use strict;
use warnings;
use C4::Context;
use DBI;
use Net::FTP;
use Net::SFTP::Foreign;
use English qw{ -no_match_vars };

our $VERSION = 1.00;

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
        my $sql = <<"ENDRET";
        select vendor_edi_accounts.*,
        aqbooksellers.name as vendor
        from vendor_edi_accounts left join aqbooksellers
        on vendor_edi_accounts.vendor_id = aqbooksellers.id
        where vendor_edi_accounts.id = ?
ENDRET
        my $dbh = C4::Context->dbh;
        my $arr_ref =
          $dbh->selectall_arrayref( $sql, { Slice => {} }, $self->{id} );
        if ( @{$arr_ref} ) {
            %{$self} = %{ $arr_ref->[0] };
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
  (description, host, username, password, vendor_id, remote_directory, san, transport)
  values (?,?,?,?,?,?,?)
END_INSSQL
        my $rv = $dbh->do(
            $sql, {},
            $self->{description}, $self->{host},
            $self->{user},        $self->{pass},
            $self->{vendor_id},   $self->{remote_directory},
            $self->{san},         $self->{transport}
        );
        $self->{id} = $dbh->{mysql_insertid};
        return $rv;

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
        return $sth->execute(
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

    if ( $self->{transport} eq 'SFTP' ) {
        return $self->sftp_download();
    }
    else {    # assume FTP
        return $self->ftp_download();
    }
}

sub download_sftp {
    my $self     = shift;
    my $type     = shift;
    my $file_ext = _get_file_ext($type);    # C = ready to retrieve E = Edifact

    my @downloaded_files;
    my $edidir = C4::Context->config('edidir');
    my $sftp   = Net::SFTP::Foreign->new(
        $self->{host},
        {
            user     => $self->{user},
            password => $self->{password},
            timeout  => 10,
        }
    );
    if ( $sftp->error ) {
        return _abort_download( undef,
            'Unable to connect to remote host: ' . $sftp->error );
    }
    $sftp->setcwd( $self->{remote_directory} )
      or _abort_download( $sftp, "Cannot change remote dir : $sftp->error" );
    my $file_list = $sftp->ls()
      or _abort_download( $sftp,
        "cannot get file list from server: $sftp->error" );
    foreach my $filename ( @{$file_list} ) {

        if ( $filename =~ m/\.$file_ext$/ ) {
            $sftp->get( $filename, "$edidir/$filename" );
            if ( $sftp->error ) {
                _abort_download( $sftp,
                    "Error retrieving $filename: $sftp->error" );

                # or log & try next
            }
            push @downloaded_files, $filename;
            my $processed_name = $filename;
            substr $processed_name, -3, 1, 'E';
            $sftp->rename( $filename, $processed_name );
        }
    }
    $sftp->disconnect;
    return @downloaded_files;
}

sub download_ftp {
    my $self     = shift;
    my $type     = shift;
    my $file_ext = _get_file_ext($type);    # C = ready to retrieve E = Edifact

    my $edidir = C4::Context->config('edidir');
    my @downloaded_files;
    my $ftp = Net::FTP->new(
        $self->{host},
        Timeout => 10,
        Passive => 1
      )
      or return _abort_download( undef,
        "Cannot connect to $self->{host}: $EVAL_ERROR" );
    $ftp->login( $self->{username}, $self->{password} )
      or _abort_download( $ftp, "Cannot login: $ftp->message()" );
    $ftp->cwd( $self->{remote_directory} )
      or _abort_download( $ftp, "Cannot change remote dir : $ftp->message()" );
    my $file_list = $ftp->ls()
      or _abort_download( $ftp, 'cannot get file list from server' );

    foreach my $filename ( @{$file_list} ) {

        if ( $filename =~ m/\.$file_ext$/ ) {

            $ftp->get( $filename, "$edidir/$filename" );

            # TBD error handling
            push @downloaded_files, $filename;
            my $processed_name = $filename;
            substr $processed_name, -3, 1, 'E';
            $ftp->rename( $filename, $processed_name );
        }
    }
    $ftp->quit;
    return @downloaded_files;
}

sub _abort_download {

    # log info if ftp open close it
    # if sftp abort
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

sub _get_file_ext {
    my $type = shift;

    # Extension format
    # 1st char Status C = Ready For pickup A = Completed E = Extracted
    # 2nd Char Standard E = Edifact
    # 3rd Char Type of message
    my %file_types = (
        QUOTE   => 'CEQ',
        INVOICE => 'CEI',
        ALL     => 'CE.',
    );
    if ( exists $file_types{$type} ) {
        return $file_types{$type};
    }
    return 'XXXX';    # non matching type
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

=head2 new

my $acc = Koha::EDI::Account->new( { id => 1, attr1 => value } );

Constructor returns an EDI::Account object with attributes as specified
in the passed hash_ref

=head2 create

my $acc = Koha::EDI::Account->create( { attr1 => value attr2 => value  );

Convenience constructor calls new and and inserts the object in the database
before returning it

=head2 retrieve

$ret = $obj->retrieve()

retrieves the data fields for Account with object's id attribute from
the database returns 1 on a successful read undef otherwise

=head2 insert

$ret = $obj->insert();

Inserts the object into permanent store as a new row
Returns the return value of the insert and sets the object's id attribute
to the approprate value

=head2 del

$ret = $obj->del()

Deletes the row corresponding to the object's id attribute from permanent
store. Returns the deletes return value or undef if no id attribute is set

=head2 update

$ret = $object->update()

Update the database with the values in the current object, requiews that id
was set either on creation or by a previous retrieve
Returns the return value from the update or undef if the id attribute was not
present.

=head2 log_last_activity

Update Account last activity date 
This can only be done by this method call it is not updated by update

=head2 download

Download new edi files from this account

=head2 id

Return the id of this account or undef if none assigned

=head2 get_all

my $accts = Koha::EDI::Account->get_all()

Class method returns an array of all vendor EDI accounts

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
