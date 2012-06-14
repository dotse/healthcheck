#!/usr/bin/env perl

use lib 'blib/lib';

use Zonestat;
use JSON::XS;
use Try::Tiny;

my $coder = JSON::XS->new->canonical->utf8->pretty;

my $dbc = Zonestat->new('t/config/Config')->dbconn;
my %res;
foreach my $db (@{$dbc->listDBs}) {
    my $i = $db->dbInfo;
    next unless $i->{db_name} =~ /^zonestat/;

    foreach my $r (map {$_->{id}} @{$db->listDocIdRevs}) {
        my $doc = $db->newDoc($r);
        try {
            $doc->retrieve;
        };
        # next if $doc->id =~ /_design/;
        push @{$res{$i->{db_name}}}, {id => $doc->id, data => $doc->data}; # if grep {$_==$doc->data->{testrun}} (14,24,36,475,58,78);
        # push @{$res{$i->{db_name}}}, {id => $doc->id, data => $doc->data} if $doc->id =~ /_design/;
    }
}

open my $fh, '>', 'fixtures.json' or die $!;

print $fh $coder->encode(\%res);
