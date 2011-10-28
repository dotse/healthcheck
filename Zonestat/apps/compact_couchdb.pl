#!/opt/local/bin/perl

=pod

Takes no arguments of any sort. Iterates over all databases in the configured
CouchDB instance and starts compactions for them.

=cut

use Zonestat;
use HTTP::Request;

my $dbc = Zonestat->new->dbconn;

foreach my $db ( @{ $dbc->listDBs } ) {
    next unless $db->dbInfo->{db_name} =~ /^zonestat/;
    my $url = $dbc->{uri} . $db->uriName . '/_compact';
    print $db->uriName, ": ";
    my $res = $dbc->{ua}->request( HTTP::Request->new( POST => $url, [ 'Content-Type', 'application/json' ] ) );
    print $res->status_line, "\n";
}
