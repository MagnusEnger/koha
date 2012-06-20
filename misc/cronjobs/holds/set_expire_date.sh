#!/bin/sh
# Script to set hold expiry date to date placed + 90 days

echo "update reserves set expirationdate = reservedate + interval 90 day where expirationdate is null" | mysql -u kohaadmin -pkoha@waht koha
