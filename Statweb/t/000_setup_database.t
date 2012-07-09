#!/usr/bin/env perl

use lib 'blib/lib';

use strict;
use warnings;

use Zonestat;
use File::Slurp;
use JSON::XS;

use Test::More;

my $zs  = Zonestat->new( 't/config/Config' );
my $dbc = $zs->dbconn;

my $prefix = $zs->cget( qw[couchdb dbprefix] );
$prefix ||= 'zonestat';

my $fix = decode_json( read_file( 't/fixtures.json' ) );
foreach my $dbname ( keys %$fix ) {
    my $realname = $dbname;
    $realname =~ s/^zonestat/$prefix/;
    my $db = $dbc->newDB($realname);
    if($dbc->dbExists($realname)) {
        $db->delete;
    }
    ok($db->create, "$realname created");
    my @docs;
    foreach my $data ( @{ $fix->{$dbname} } ) {
        my $doc = $db->newDoc($data->{id}, undef, $data->{data});
        push @docs, $doc;
    }
    $db->bulkStore(\@docs);
}

eval {
    ok $zs->user->create('someuser', 'somepwd', 'Some User', 'some@example.org');
};

# $zs->prepare->update_asn_table_from_ripe;

done_testing;