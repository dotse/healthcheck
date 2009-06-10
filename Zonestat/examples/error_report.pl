#!/usr/bin/perl

use warnings;
use strict;

use Zonestat;

my $zs = Zonestat->new('/opt/local/share/dnscheck/site_config.yaml');
my @data = $zs->present->number_of_domains_with_message;

foreach my $i (@data) {
    printf("%5d: %s\n", $i->[1], $i->[0]);
}
