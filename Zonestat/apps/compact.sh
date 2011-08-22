#!/bin/bash

DBURL=http://127.0.0.1:5984/

for db in `echo couchdb/*`
do
    dbname=`basename $db`
    echo -n "Cleaning $dbname: "
    curl -X POST -H 'Content-Type: application/json' $DBURL$dbname/_view_cleanup
    echo -n "Compacting $dbname: "
    curl -X POST -H 'Content-Type: application/json' $DBURL$dbname/_compact
    for design in `echo couchdb/$dbname/_design/*`
    do
        designname=`basename $design`
        echo -n "Compacting $dbname/$designname: "
        curl -X POST -H 'Content-Type: application/json' $DBURL$dbname/_compact/$designname
    done
done