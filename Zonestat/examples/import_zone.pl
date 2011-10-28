#!/usr/bin/perl

=pod

Runs a zone import followed by generation of a random subset. Almost certainly
not useful if you're not .SE.

=cut

use warnings;
use strict;

use Zonestat;

my $prep = Zonestat->new->prepare;

if ( $prep->fetch_zone ) {
    $prep->db_import_zone;
    $prep->create_random_set;
}
else {
    print STDERR "Failed to download zone.\n";
}
