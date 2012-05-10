#!/usr/bin/env perl

use lib 'blib/lib';

use strict;
use warnings;

use Zonestat;
use File::Slurp;
use JSON::XS;

my $zs  = Zonestat->new( 't/Config' );
my $dbc = $zs->dbconn;

my $prefix = $zs->cget( qw[couchdb dbprefix] );
$prefix ||= 'zonestat';

my $fix = decode_json( read_file( 't/fixtures.json' ) );
foreach my $dbname ( keys %$fix ) {
    my $realname = $dbname;
    $realname =~ s/^zonestat/$prefix/;
    my $db = $dbc->newDB($realname);
    if($dbc->dbExists($realname)) {
        print "$realname exists\n";
        $db->delete;
    } else {
        print "$realname does not exist.\n";
    }
    $db->create;
    foreach my $data ( @{ $fix->{$dbname} } ) {
        print $data->{id} . "\n";
        my $doc = $db->newDoc($data->{id}, undef, $data->{data});
        $doc->create;
    }
}
