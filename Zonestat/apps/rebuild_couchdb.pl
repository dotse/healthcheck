#!/opt/local/bin/perl

use Zonestat;
use HTTP::Request;

my $dbc = Zonestat->new->dbconn;

foreach my $db (@{ $dbc->listDBs }) {
    next unless $db->dbInfo->{db_name} =~ /^zonestat/;
    foreach my $ddoc (@{ $db->listDesignDocs(startkey => '_', endkey => '`') })
    {
        $ddoc->retrieve;
        foreach my $view ($ddoc->listViews) {
            printf(
                "%s%s/%s/_view/%s\n",
                $dbc->{uri}, $db->dbInfo->{db_name},
                $ddoc->id, $view
            );
            $ddoc->queryView($view);
        }
    }
}
