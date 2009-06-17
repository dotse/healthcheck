#!/opt/local/bin/perl -l

use Zonestat;
use Data::Dumper;

my $zs = Zonestat->new('/opt/local/share/dnscheck/site_config.yaml');
my $schema = Zonestat::DBI->connect($zs->dbconfig);
my $table = $schema->resultset('Domains');

my $d = $table->search({domain => 'iis.se'})->first;
foreach my $t ($d->tests) {
    printf "Test #%d ran from %s to %s and produced %d result rows.\n", $t->id, $t->begin, $t->end, scalar($t->results);
}