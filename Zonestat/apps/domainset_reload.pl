#!/usr/bin/env perl

use 5.10.0;

use strict;
use warnings;

use Zonestat;

unless (scalar(@ARGV)==2) {
    say "usage: $0 name_of_set name_of_file_with_domains";
    exit(2);
}

my ($name, $file) = @ARGV;

open my $fh, '<', $file or die "Failed to open $file: $!\n";
binmode $fh, ':utf8';

my @names = <$fh>;
chomp(@names);

my $ds = Zonestat->new->domainset($name);

$ds->clear;
$ds->add(@names);

say "Domainset $name now contains " . scalar(@{$ds->all}) . ' domains.';
