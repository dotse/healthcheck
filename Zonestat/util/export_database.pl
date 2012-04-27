#!/usr/bin/env perl

use lib 'blib/lib';

use Zonestat;
use JSON::XS;

my $coder = JSON::XS->new->canonical->utf8->pretty;

my $dbc = Zonestat->new('t/Config')->dbconn;
my %res;
foreach my $db (@{$dbc->listDBs}) {
    my $i = $db->dbInfo;
    next unless $i->{db_name} =~ /^zonestat/;

    foreach my $r (map {$_->{id}} @{$db->listDocIdRevs}) {
        my $doc = $db->newDoc($r);
        $doc->retrieve;
        next if $doc->id =~ /_design/;
        push @{$res{$i->{db_name}}}, {id => $doc->id, data => $doc->data};
    }
}

open my $fh, '>', 'fixtures.json' or die $!;

print $fh $coder->encode(\%res);
