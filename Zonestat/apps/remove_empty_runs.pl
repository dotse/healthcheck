#!/usr/bin/env perl

=pod

Iterates over all domainsets, and deletes any testruns they have with no
gathered domains in them. Do not run while a gathering run is in progress.

=cut

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
