package Koha::EDI::Transport;
use strict;
use warnings;
use DateTime;
use Carp;
use English qw{ -no_match_vars };
use Net::FTP;
use Net::SFTP::Foreign;
use File::Slurp;
use File::Copy;
use File::Basename qw( fileparse );
use Koha::Database;

sub new {
    my ( $class, $account_id ) = @_;
    my $database = Koha::Database->new();
    my $schema   = $database->schema();
    my $acct     = $schema->resultset('VendorEdiAccount')->find($account_id);
    my $self     = {
        account     => $acct,
        schema      => $schema,
        working_dir => '/tmp',    #temporary work directory
        transfer_date => DateTime->now( time_zone => 'local' ),
    };

    bless $self, $class;
    return $self;
}

sub working_directory {
    my ( $self, $new_value ) = @_;
    if ($new_value) {
        $self->{working_directory} = $new_value;
    }
    return $self->{working_directory};
}

sub download_messages {
    my ( $self, $message_type, @direct_params ) = @_;
    $self->{message_type} = $message_type;
    if ( $self->{direct} ) {
        return $self->direct_read(@direct_params);
    }

    my @retrieved_files;

    if ( $self->account->transport eq 'SFTP' ) {
        @retrieved_files = $self->sftp_download();
    }
    else {    # assume FTP
        @retrieved_files = $self->ftp_download();
    }
    return @retrieved_files;
}

sub upload_messages {
    my ( $self, @messages ) = @_;
    if (@messages) {
        if ( $self->account->transport eq 'SFTP' ) {
            $self->sftp_upload_messages();
        }
        else {    # assume FTP
            $self->ftp_upload_messages();
        }
    }
    return;
}

sub direct_read {
    my ( $self, @files ) = @_;

    my $file_ext = _get_file_ext( $self->{message_type} );
    my $msg_hash = $self->message_hash();
    my @downloaded_files;
    foreach my $filename (@files) {
        if ( $filename =~ m/[.]$file_ext$/ ) {

            copy( $filename, $self->{working_dir} )
              or croak "Copy of $filename failed: $!";
            my $f = fileparse($filename);
            push @downloaded_files, $f;
        }
    }
    $self->ingest( $msg_hash, @downloaded_files );
    return @downloaded_files;
}

sub sftp_download {
    my $self = shift;

    my $file_ext = _get_file_ext( $self->{message_type} );

    # C = ready to retrieve E = Edifact
    my $msg_hash = $self->message_hash();
    my @downloaded_files;
    my $sftp = Net::SFTP::Foreign->new(
        $self->{account}->host,
        {
            user     => $self->{account}->user,
            password => $self->{account}->password,
            timeout  => 10,
        }
    );
    if ( $sftp->error ) {
        return _abort_download( undef,
            'Unable to connect to remote host: ' . $sftp->error );
    }
    $sftp->setcwd( $self->{account}->directory )
      or _abort_download( $sftp, "Cannot change remote dir : $sftp->error" );
    my $file_list = $sftp->ls()
      or _abort_download( $sftp,
        "cannot get file list from server: $sftp->error" );
    foreach my $filename ( @{$file_list} ) {

        if ( $filename =~ m/[.]$file_ext$/ ) {
            $sftp->get( $filename, "$self->{working_dir}/$filename" );
            if ( $sftp->error ) {
                _abort_download( $sftp,
                    "Error retrieving $filename: $sftp->error" );
                last;
            }
            push @downloaded_files, $filename;
            my $processed_name = $filename;
            substr $processed_name, -3, 1, 'E';
            $sftp->rename( $filename, $processed_name );
        }
    }
    $sftp->disconnect;
    $self->ingest( $msg_hash, @downloaded_files );

    return @downloaded_files;
}

sub ingest {
    my ( $self, $msg_hash, @downloaded_files ) = @_;
    foreach my $f (@downloaded_files) {
        $msg_hash->{filename} = $f;
        my @lines = read_file("$self->{working_dir}/$f");
        if ( !defined $lines[0] ) {
            carp "Unable to read download file $f";
            next;
        }
        for (@lines) {
            chomp;
            s/\r$//;
        }
        $msg_hash->{raw_msg} = join q{}, @lines;
        $self->{schema}->resultset('EdifactMessage')->create($msg_hash);
    }
    return;
}

sub ftp_download {
    my $self = shift;

    my $file_ext = _get_file_ext( $self->{message_type} );

    # C = ready to retrieve E = Edifact

    my $msg_hash = $self->message_hash();
    my @downloaded_files;
    my $ftp = Net::FTP->new(
        $self->{account}->host,
        Timeout => 10,
        Passive => 1
      )
      or return _abort_download( undef,
        "Cannot connect to $self->{account}->host: $EVAL_ERROR" );
    $ftp->login( $self->{account}->username, $self->{account}->password )
      or _abort_download( $ftp, "Cannot login: $ftp->message()" );
    $ftp->cwd( $self->{account}->directory )
      or _abort_download( $ftp, "Cannot change remote dir : $ftp->message()" );
    my $file_list = $ftp->ls()
      or _abort_download( $ftp, 'cannot get file list from server' );

    foreach my $filename ( @{$file_list} ) {

        if ( $filename =~ m/[.]$file_ext$/ ) {

            if ( !$ftp->get( $filename, "$self->{working_dir}/$filename" ) ) {
                _abort_download( $ftp,
                    "Error retrieving $filename: $ftp->message" );
                last;
            }

            push @downloaded_files, $filename;
            my $processed_name = $filename;
            substr $processed_name, -3, 1, 'E';
            $ftp->rename( $filename, $processed_name );
        }
    }
    $ftp->quit;

    $self->ingest( $msg_hash, @downloaded_files );

    return @downloaded_files;
}

sub ftp_upload {
    my ( $self, @messages ) = @_;
    my $ftp = Net::FTP->new(
        $self->{account}->host,
        Timeout => 10,
        Passive => 1
      )
      or return _abort_download( undef,
        "Cannot connect to $self->{account}->host: $EVAL_ERROR" );
    $ftp->login( $self->{account}->username, $self->{account}->password )
      or _abort_download( $ftp, "Cannot login: $ftp->message()" );
    $ftp->cwd( $self->{account}->directory )
      or _abort_download( $ftp, "Cannot change remote dir : $ftp->message()" );
    foreach my $m (@messages) {
        my $content = $m->raw_msg;
        if ($content) {
            open my $fh, '<', \$content;
            if ( $ftp->put( $fh, $m->filename ) ) {
                close $fh;
                $m->transfer_date( $self->{transfer_date} );
                $m->status('sent');
                $m->update;
            }
            else {
                # error in transfer

            }
        }
    }

    $ftp->quit;
    return;
}

sub sftp_upload {
    my ( $self, @messages ) = @_;
    my $sftp = Net::SFTP::Foreign->new(
        $self->{account}->host,
        {
            user     => $self->{account}->user,
            password => $self->{account}->password,
            timeout  => 10,
        }
    );
    $sftp->die_on_error("Cannot ssh to $self->{account}->host");
    $sftp->cwd( $self->{account}->directory );
    $sftp->die_on_error('Cannot change to remote dir');
    foreach my $m (@messages) {
        my $content = $m->raw_msg;
        if ($content) {
            open my $fh, '<', \$content;
            if ( $sftp->put( $fh, $m->filename ) ) {
                close $fh;
                $m->transfer_date( $self->{transfer_date} );
                $m->status('sent');
                $m->update;
            }
            else {
                # error in transfer

            }
        }
    }

    # sftp will be closed on object destructor
    return;
}

sub _abort_download {
    my ( $handle, $log_message ) = @_;

    $handle->abort();
    carp $log_message;

    #returns undef i.e. an empty array
    return;
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

sub message_hash {
    my $self = shift;
    my $msg  = {
        message_type  => $self->{message_type},
        vendor_id     => $self->{account}->vendor_id,
        status        => 'new',
        deleted       => 0,
        transfer_date => $self->{transfer_date}->ymd(),
    };

    return $msg;
}

### allow direct ingesting
sub set_transport_direct {
    my $self = shift;

    $self->{direct} = 1;
    return;
}
1;
