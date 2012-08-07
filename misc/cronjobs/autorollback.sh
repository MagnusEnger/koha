#!/bin/bash
#
# Script to rollback the demo to a standard base.
#
# If you wish to modify the current state of that database.. do your modifications as normal in koha and then do a database dump and over write the previose model
#
mysql -u root -pmelB1n koha_test < /home/koha/koha-rollback/rollback.sql

date=`date +%d/%m/%Y`
date1=`date -d +2days +%d/%m/%Y`
date2=`date +%F`
date3=`date -d +3days +%F`
file=/home/test/koha-rollback/rollback.sql

sed -i "s|$date|$date1|g" "$file"
sed -i "s|$date2|$date3|g" "$file"
