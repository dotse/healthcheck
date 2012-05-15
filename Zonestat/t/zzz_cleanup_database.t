#!/usr/bin/env perl

use lib 'blib/lib';

use strict;
use warnings;

use Zonestat;

use Test::More;

my $zs  = Zonestat->new( 't/Config' );
my $dbc = $zs->dbconn;

my $prefix = $zs->cget( qw[couchdb dbprefix] );
$prefix ||= 'zonestat';

foreach my $name (@{$dbc->listDBNames}) {
    next unless $name =~ /^$prefix/;
    ok($dbc->newDB($name)->delete, "$name deleted");
}

done_testing;