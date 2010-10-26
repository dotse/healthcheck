#!/opt/local/bin/perl

use strict;
use warnings;

use CouchDB::Helper;

install_to_couchdb($ENV{COUCHDB_URL} || 'http://127.0.0.1:5984/');