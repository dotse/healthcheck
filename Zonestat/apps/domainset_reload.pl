#!/usr/bin/env perl

=pod

Reload the names in a domainset from a file. Takes two arguments exactly, the
name of the domainset and the name of the file with the domainnames to load
into it.

=cut

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
