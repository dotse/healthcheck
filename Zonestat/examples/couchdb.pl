#!/opt/local/bin/perl

use strict;
use warnings;

use CouchDB::Client;
use Zonestat;
use Try::Tiny;

my @domains   = qw[iis.se google.se handelsbanken.se lysator.liu.se];
my $collector = Zonestat->new->collect;

my $c = CouchDB::Client->new( uri => 'http://127.0.0.1:5984/' );
$c->testConnection or die "Nope!";
my $db = $c->newDB( 'zonestat' );

try {
    $db->dbInfo;
}
catch {
    print "Creating database.\n";
    $db->create;
};

foreach my $d ( @domains ) {
    print "Starting gather for $d.\n";
    my $res = $collector->for_domain( $d );
    my $doc = $db->newDoc( undef, undef, $res );
    $doc->create;
    print "$d saved.\n";
}
