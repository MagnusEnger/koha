#!/bin/bash
# Script to add a new customisation file for a translation

echo -n " Please enter the translation file you would like to customise: "
read translation
echo -n " Please enter the translation code this file belongs to (e.g. en-GB): "
read tr_code
echo -n " Please enter the customer code: "
read cust_code

if [ ! -d "./po/custom" ]; then
    echo " Creating /po/custom dir..."
    mkdir ./po/custom
fi

if [ -f ./po/custom/${translation} ]; then
    echo " Skipping creation of base translation file..."
fi

if [ ! -f ./po/custom/${translation} ]; then
    echo " Creating base translation file..."
    cp ./po/${translation} ./po/custom/${translation}
fi

if [ -f ./po/custom/${translation}_${cust_code} ]; then
    echo " Customisation file found..."
    echo " Applying customisations..."
    cat ./po/custom/${translation} ./po/custom/${translation}_${cust_code} > ./po/${translation}
    perl translate install ${tr_code}
    echo " Done..."
    echo " Have you commited ${translation}_${cust_code} to git yet? ******"
fi
	    
if [ ! -f ./po/custom/${translation}_${cust_code} ]; then
    echo " Creating customisation file..."
    touch ./po/custom/${translation}_${cust_code}
    echo " Please go forth and add your customisations to ./po/custom/${translation}_${cust_code} and re-run this script"
fi
