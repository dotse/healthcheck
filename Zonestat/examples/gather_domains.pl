#!/opt/local/bin/perl

use warnings;
use strict;

use Zonestat;

STDOUT->autoflush(1);

my $zs = Zonestat->new;

$zs->gather->put_in_queue(
    map { { domain => $_, priority => 1 + int(rand(10)) } } @ARGV);
