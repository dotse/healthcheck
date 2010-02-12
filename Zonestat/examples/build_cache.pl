#!/opt/local/bin/perl

use strict;
use warnings;

use Zonestat;

my $zs = Zonestat->new;

my $trs = $zs->dbx('Testrun');
my $pr = $zs->present;

$| = 1;

while(my $tr = $trs->next) {
    printf "About to build cache for %s %s...",$tr->domainset->name, $tr->name;
    $pr->build_cache_for_testrun($tr);
    print "done.\n"
}