#!/usr/bin/perl
use strict;
use warnings;
use 5.010;
# CPAN Imports
use Text::CSV;
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
my $file = "people.csv";
my $backup = "past/people-$today.csv";
my $csv = Text::CSV->new();
# DB
my $dbh = C4::Context->dbh;
my $bor_insert = $dbh->prepare_cached(
'INSERT INTO borrowers(cardnumber,surname,firstname,othernames,address,email,branchcode,categorycode,password,userid) VALUES (?,?,?,?,?,?,?,?,?,?) ON DUPLICATE KEY UPDATE surname=VALUES(surname),firstname=VALUES(firstname),othernames=VALUES(othernames),address=VALUES(address),email=VALUES(email),branchcode=VALUES(branchcode),password=VALUES(password),userid=VALUES(userid);'
);

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

	# Capitalise Branch
	my $branch = uc( $columns[5] );
	$branch =~ s/\s//g;
	$branch =~ s/^NULL/FIRMWIDE/g;
	$branch =~ s/^DUBAI/UAE/g;
	$branch =~ s/^SOUTHAFRICA/FIRMWIDE/g;
	
	# Insert into 'borrowers'
        $bor_insert->execute(
            $columns[2],	$columns[0],	$firstname,
            $othernames,	$columns[6],	$columns[4],
            $branch,		$category,	$password,
	    $columns[3]
        );	    
	
	print "Record: " . $count . "\n";
	print "Cardnumber: $columns[2]\n";
        print "Surname: $columns[0]\n";
	print "Firstname: $firstname\n";
        print "Othernames: $othernames\n";
	print "Address: $columns[6]\n";
	print "Email: $columns[4]\n";
	print "Branch: $branch\n";
	print "Category: $category\n";
	print "Password: $password\n";
	print "Username: $columns[3]\n";
        
	#print "Forenames: $columns[1]\n";
        #print "EmployeeID: $columns[2]\n";
        #print "Username: $columns[3]\n";
        #print "Email: $columns[4]\n";
        #print "Location: $columns[5]\n";
        #print "Room Number: $columns[6]\n";
        print "\n\n";
    }
    else {
        my $err = $csv->error_input;
        push(@errors, $err);
	$fails++;
        #print "Parsing Line: " . $count . ". Failed to parse line: $err";
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

