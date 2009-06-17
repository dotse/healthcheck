#!/usr/bin/perl

use warnings;
use strict;

use Zonestat;

my $zs    = Zonestat->new('/opt/local/share/dnscheck/site_config.yaml');
my @data  = $zs->present->number_of_domains_with_message;
my $total = $zs->present->total_tested_domains;

foreach my $i (@data) {
    printf("%5.2f%% %s\n", ($i->[1] / $total) * 100, $i->[0]);
}
