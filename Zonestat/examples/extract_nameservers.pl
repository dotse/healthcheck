#!/usr/bin/env perl

=pod

This script was used during development. It's left as an example of how one
can mess around with the CouchDB data from Perl. It is not in any way useful
in itself.

=cut

use strict;
use warnings;

use Zonestat;
use Data::Dumper;

my $zs   = Zonestat->new;
my $zdbp = $zs->dbproxy( 'zonestat' );
my $tmp  = $zdbp->server_ns_count( group => 1 );

my $nsdb = $zs->db( 'zonestat-nameserver' );

foreach my $doc ( @{ $tmp->{rows} } ) {
    my ( $runid, $ipversion, $address ) = @{ $doc->{key} };
    next unless $runid;
    my $id = "$runid-$address";
    $nsdb->newDoc( $id, undef, { testrun => $runid, address => $address, ipversion => $ipversion } )->create
      unless $nsdb->docExists( $id );
}

my $res = $zs->dbproxy( 'zonestat-nameserver' )->ns_count(
    group_level => 2,
    startkey    => [ "4", "4" ],
    endkey      => [ "4", "5" ],
    group       => 1
);
print Dumper( $res );
