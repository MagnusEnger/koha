#!/usr/bin/perl
use strict;
use warnings;
use 5.010;
# CPAN Imports
use Text::CSV::Encoded;
use Digest::MD5 qw(md5_base64);
# Koha Imports
use C4::Context;

#
# Variables
#

# Date
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
  localtime(time);

$year += 1900;
$mon++;

$mday = '0' . $mday if ( $mday < 10 );                   # Zero Padding
$mon  = '0' . $mon  if ( $mon < 10 );                    # Zero Padding

my $today  = "$mday-$mon-$year";

#
# Workflow
#

# File
my $path = "/home/syncuser/imports/";
my $file = "People.csv";
my $backup = "past/people-$today.csv";
my $csv = Text::CSV::Encoded->new({encoding => "utf8", });
# DB
my $dbh = C4::Context->dbh;
my $bor_insert = $dbh->prepare_cached(
'INSERT INTO borrowers(cardnumber,surname,firstname,othernames,address,email,branchcode,categorycode,password,userid) VALUES (?,?,?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE surname=VALUES(surname),firstname=VALUES(firstname),othernames=VALUES(othernames),address=VALUES(address),email=VALUES(email),branchcode=VALUES(branchcode),password=VALUES(password),userid=VALUES(userid);'
);
my $branch_query = $dbh->prepare_cached(
'SELECT branchname, branchcode FROM branches;'
);

# Build hash of branches
my %branches;
$branch_query->execute() or die "Can't execute query: $branch_query->errstr\n";
while ( ($branchname, $branchcode) = $branch_query->fetchrow_array() ) {
     $branches{$branchname} = $branchcode;
}
$branch_query->finish();

# Import Users
open( IMPORT, "<", "$path/$file" ) or die $!;

my $count  = 0;
my $fails  = 0;
my @errors;
 
while (<IMPORT>) {
$count++;
    if ( $csv->parse($_) ) {
        my @columns = $csv->fields();

	# Split Forenames
	my @names = split( / /, $columns[1] );
	my $firstname = $names[0];
	shift(@names);
	my $othernames = "@names";

	# Create Password
	my $password = md5_base64( $columns[0] );	

	# Category
	my $category = "USER";

	# Check Branch
	my $branch = $columns[5];
        if ( exists $branches{$branch} ) {
            $branch = $branches{$branch};
        }
        elsif ( $branch eq "Dubai" ) {
            $branch = 'UAE';
        }
        else {
            $branch = 'FIRMWIDE';
        }
	
	# Insert into 'borrowers'
        $bor_insert->execute(
            $columns[2],	$columns[0],	$firstname,
            $othernames,	$columns[6],	$columns[4],
            $branch,		$category,	$password,
	    $columns[3]
        );	    
    }
    else {
        my $err = $csv->error_input;
        push(@errors, $err);
	$fails++;
    }
}
print "Number of Fails: " . $fails . "\n";
print @errors;
close IMPORT;

# Move file to backup
system(
    "sudo", "mv",
    "$path/$file",
    "$path/$backup"
);

# Compress backup
system(
    "sudo", "gzip",
    "$path/$backup"
);
