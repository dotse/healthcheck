#!/usr/bin/perl

use warnings;
use strict;

use Zonestat;

my $prep = Zonestat->new->prepare;

if ($prep->fetch_zone) {
    $prep->db_import_zone;
    # $prep->create_random_set;
} else {
    print STDERR "Failed to download zone.\n";
}
