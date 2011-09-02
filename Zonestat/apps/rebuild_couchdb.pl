#!/opt/local/bin/perl

use Zonestat;
use HTTP::Request;
use LWP::UserAgent;

my $zs  = Zonestat->new;
my $dbc = CouchDB::Client->new(
    ua       => LWP::UserAgent->new( timeout => 1 ),
    uri      => $zs->dbconfig->{url},
    username => $zs->dbconfig->{username},
    password => $zs->dbconfig->{password},
);

foreach my $db ( @{ $dbc->listDBs } ) {
    next unless $db->dbInfo->{db_name} =~ /^zonestat/;
    foreach my $ddoc ( @{ $db->listDesignDocs( startkey => '_', endkey => '`' ) } ) {
        $ddoc->retrieve;
        my $view = ( $ddoc->listViews )[0];

        # printf( "%s%s/%s/_view/%s\n", $dbc->{uri}, $db->dbInfo->{db_name}, $ddoc->id, $view );
        eval { $ddoc->queryView( $view ); };
    }
}
