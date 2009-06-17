#!/opt/local/bin/perl -l

use Zonestat;
use Data::Dumper;

my $zs     = Zonestat->new('/opt/local/share/dnscheck/site_config.yaml');
my $schema = Zonestat::DBI->connect($zs->dbconfig);
my $table  = $schema->resultset('Tests');

my $rs = $table->search({ count_error => { '>' => 0 } });

while (my $r = $rs->next) {
    printf "#%d: %s has %d errors.\n", $r->id, $r->domain, $r->count_error;
}
