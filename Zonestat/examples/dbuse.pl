#!/opt/local/bin/perl -l

use Zonestat;

my $zs = Zonestat->new('/opt/local/share/dnscheck/site_config.yaml');
my $schema = Zonestat::DBI->connect($zs->dbconfig);
my $rs = $schema->resultset('Zone');
print $rs->find(4711)->name;