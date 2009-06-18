#!/opt/local/bin/perl -l

use Zonestat;

my $gather =
  Zonestat->new('/opt/local/share/dnscheck/site_config.yaml')->gather;

my $table =
  $gather->dbx('Domains')
  ->search({}, { order_by => 'rand()', rows => $ARGV[0] });

print STDERR "Building list...";
my @list = map { $_->domain } $table->all;

print STDERR "Gathering...";
$gather->get_http_server_data(@list);
my $ws = $gather->dbx('Webserver')->search({});

while (my $row = $ws->next) {

    #printf "Domain %s has a server of type %s version %s.\n",
    #  $row->domain->domain, $row->type, $row->version;
    if ($row->type eq 'Unknown') {
        print "\t", $row->raw;
    }

}
