#!/usr/bin/perl

use warnings;
use strict;

use Carp;
use Net::FTP;
use Net::FTP::File;
use C4::Context;
use Koha::EDI;

my $idir       = C4::Context->config('intranetdir');
my $edidir     = "$idir/misc/edi_files/";
my $ftplogfile = "$edidir/edi_ftp.log";

my @bertrams_ftp_accounts = (
    {
        server  => 'ftp.server.com',
        vendor  => 'Test vendor',
        ftpuser => 'username',
        ftppass => 'password',
        ftpdir  => '/directory',
    },
);

# construct an array of hash_ref containing Bertrams FTP details (server, vendor, ftpuser, ftppass, ftpdir)

# downloads files and returns an array of hashes containing each message details (filename, message_content, ftp_account)
my @downloaded_messages = download_messages( \@bertrams_ftp_accounts );

# returns an array of hashes for files to be written to disk then transferred to Bertrams server (filename, message_content)
my @split_messages = split_messages( \@downloaded_messages );

# splits downloaded messages into separate messages and returns hash containing messages to be written to files and uploaded
sub split_messages {
    my $file_prefix = 1;
    my ($downloaded_messages) = @_;
    foreach my $downloaded_message (@$downloaded_messages) {
        $downloaded_message->{message_content} =~ s/UNH/~~~UNH/g;

        my $unzpos = rindex( $downloaded_message->{message_content}, 'UNZ' );

        my $unz = substr( $downloaded_message->{message_content}, $unzpos );

        #change number of messages to 1
        $unz =~ m/UNZ\+(.*?)\+(.*?)'/;
        $unz = "UNZ+1+" . $2 . "'";

        $downloaded_message->{message_content} =
          substr( $downloaded_message->{message_content}, 0, $unzpos );

        my @messages = split( /~~~/, $downloaded_message->{message_content} );

        my $una = $messages[0];

        shift(@messages);

        my $newmessage;

        foreach my $message (@messages) {
            $newmessage = {
                filename => $file_prefix . '_'
                  . $downloaded_message->{filename},
                una         => $una,
                lineitems   => $message,
                unz         => $unz,
                ftp_account => $downloaded_message->{ftp_account},
            };
            create_new_message($newmessage);
            $file_prefix++;
        }

        # rename original message file on remote server
        my $ftp = Net::FTP->new( $downloaded_message->{ftp_account}->{server},
            Timeout => 10 )
          or croak "Couldn't connect";
        $ftp->login(
            $downloaded_message->{ftp_account}->{ftpuser},
            $downloaded_message->{ftp_account}->{ftppass}
        ) or croak "Couldn't log in";
        $ftp->cwd( $downloaded_message->{ftp_account}->{ftpdir} )
          or croak "Couldn't change directory";

        ### rename file
        my $rext         = '.EEI';
        my $qext         = '.CEI';
        my $new_filename = $downloaded_message->{filename};
        $new_filename =~ s/$qext/$rext/g;
        $ftp->rename( $downloaded_message->{filename}, $new_filename )
          or croak "Couldn't rename remote file";
        print "Original message file renamed to prevent duplicate processing\n";
    }
}

sub create_new_message {
    my $message = shift;
    open my $fh, '>>', $edidir . $message->{filename}
      or croak "Could not open $message->{filename}: $!";
    print $fh $message->{una};
    print $fh $message->{lineitems};
    print $fh $message->{unz};
    close $fh;
    print $edidir. $message->{filename} . " successfully created\n";
    send_new_message( $message->{filename}, $message->{ftp_account} );
    return;
}

sub send_new_message {
    my ( $filename, $ftpaccount, $new_message ) = @_;
    my @errors;
    my $newerr;
    my $result;

    open my $log_fh, '>>', $ftplogfile
      or croak "Could not open $ftplogfile: $!";
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime(time);
    printf $log_fh "\n\n%4d-%02d-%02d %02d:%02d:%02d\n-----\n", $year + 1900,
      $mon + 1, $mday, $hour, $min, $sec;

    # check edi message file exists
    if ( -e $edidir . $filename ) {
        use Net::FTP;

        print $log_fh "Connecting to " . $ftpaccount->{server} . "... ";

        # connect to ftp account
        my $ftp =
          Net::FTP->new( $ftpaccount->{server}, Timeout => 10, Passive => 1 )
          or $newerr = 1;
        push @errors, "Can't ftp to " . $ftpaccount->{server} . ": $!\n"
          if $newerr;
        myerr(@errors) if $newerr;
        if ( !$newerr ) {
            $newerr = 0;
            print $log_fh "connected.\n";

            # login
            $ftp->login( "$ftpaccount->{ftpuser}", "$ftpaccount->{ftppass}" )
              or $newerr = 1;
            $ftp->quit if $newerr;
            print $log_fh "Logging in...\n";
            push @errors, "Can't login to " . $ftpaccount->{server} . ": $!\n"
              if $newerr;
            myerr(@errors) if $newerr;
            if ( !$newerr ) {
                print $log_fh "Logged in\n";

                # cd to directory
                $ftp->cwd("$ftpaccount->{ftpdir}") or $newerr = 1;
                push @errors,
                  "Can't cd in server " . $ftpaccount->{server} . " $!\n"
                  if $newerr;
                myerr(@errors) if $newerr;
                $ftp->quit if $newerr;

                # put file
                if ( !$newerr ) {
                    $newerr = 0;
                    $ftp->put( $edidir . $filename ) or $newerr = 1;
                    push @errors,
                      "Can't write message file to server "
                      . $ftpaccount->{server} . " $!\n"
                      if $newerr;
                    myerr(@errors) if $newerr;
                    $ftp->quit if $newerr;
                    if ( !$newerr ) {
                        print $log_fh
                          "File: $edidir$filename transferred successfully\n";
                        print
                          "File: $edidir$filename transferred successfully\n";
                        $ftp->quit;
                        unlink( $edidir . $filename )
                          or croak
                          "Could not delete local file: $edidir$filename\n";
                        print "Local file: $edidir$filename deleted\n";
                    }
                }
            }
        }
    }
    else {
        print $log_fh "Message file $edidir$filename does not exist\n";
        print "Message file $edidir$filename does not exist\n";
    }
    close $log_fh;
    return;
}

sub download_messages {
    my ($ftp_accounts) = @_;
    my @local_files;
    foreach my $account ( @{$ftp_accounts} ) {

        #get vendor details
        print "server: $account->{server}\n";
        print "account: $account->{vendor}\n";

        #get files
        my $newerr;
        my @errors;
        my @files;
        open my $edi_log_fh, '>>', $ftplogfile
          or croak "Could not open $ftplogfile:$!";
        my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime(time);
        printf $edi_log_fh "\n\n%4d-%02d-%02d %02d:%02d:%02d\n-----\n",
          $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
        print $edi_log_fh "Connecting to " . $account->{server} . "... ";
        my $ftp =
          Net::FTP->new( $account->{server}, Timeout => 10, Passive => 1 )
          or $newerr = 1;
        push @errors, "Can't ftp to " . $account->{server} . ": $!\n"
          if $newerr;
        myerr(@errors) if $newerr;

        if ( !$newerr ) {
            $newerr = 0;
            print $edi_log_fh "connected.\n";

            $ftp->login( $account->{ftpuser}, $account->{ftppass} )
              or $newerr = 1;
            print $edi_log_fh "Getting file list\n";
            push @errors, "Can't login to " . $account->{server} . ": $!\n"
              if $newerr;
            $ftp->quit if $newerr;
            myerr(@errors) if $newerr;
            if ( !$newerr ) {
                print $edi_log_fh "Logged in\n";
                $ftp->cwd( $account->{ftpdir} ) or $newerr = 1;
                push @errors,
                  "Can't cd in server " . $account->{server} . " $!\n"
                  if $newerr;
                myerr(@errors) if $newerr;
                $ftp->quit if $newerr;

                @files = $ftp->ls or $newerr = 1;
                push @errors,
                  "Can't get file list from server "
                  . $account->{server} . " $!\n"
                  if $newerr;
                myerr(@errors) if $newerr;
                if ( !$newerr ) {
                    print $edi_log_fh "Got  file list\n";
                    foreach (@files) {
                        my $filename = $_;
                        if ( ( index lc($filename), '.cei' ) > -1 ) {
                            my $description = sprintf "%s/%s",
                              $account->{server}, $filename;
                            print $edi_log_fh "Found file: $description - ";

                            chdir $edidir;
                            $ftp->get($filename) or $newerr = 1;
                            push @errors,
                              "Can't transfer file ($filename) from "
                              . "$account->{server} $!\n"
                              if $newerr;
                            $ftp->quit if $newerr;
                            myerr(@errors) if $newerr;
                            if ( !$newerr ) {
                                print $edi_log_fh "File retrieved\n";
                                open my $f, '<', "$edidir/$filename"
                                  or croak "Couldn't open file: $!\n";
                                my $message_content = join '', <$f>;
                                close $f;
                                my $message_file = {
                                    filename        => $filename,
                                    message_content => $message_content,
                                    ftp_account     => $account,
                                };
                                push( @local_files, $message_file );
                            }
                        }
                    }
                }
            }

            $ftp->quit;
        }
        close $edi_log_fh;
        $newerr = 0;
    }
    return @local_files;
}

sub myerr {
    my @errors = @_;
    open my $fh, '>>', $ftplogfile or croak "Could not open $ftplogfile: $!";
    print $fh "Error: ", @errors;
    close $fh;
    return;
}
