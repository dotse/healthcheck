#!/usr/bin/env perl

use strict;
use warnings;

use Zonestat;

my $zs = Zonestat->new;

foreach my $ds ( $zs->domainset->all_sets ) {
    foreach my $tr ( $ds->testruns ) {
        if ( $tr->test_count == 0 ) {
            print 'Deleting testrun ' . $tr->name . "\n";
            $tr->{doc}->delete;
        }
    }
}
