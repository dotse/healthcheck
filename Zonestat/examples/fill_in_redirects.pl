#!/opt/local/bin/perl -l

use warnings;
use strict;

use Zonestat;

my $db = Zonestat->new->present->dbx('Webserver');

while (my $ws = $db->next) {
    my $res    = $ws->raw_response;
    my $rcount = scalar($res->redirects);
    my $rurls  = join ' ', map { $_->base } $res->redirects;
    $rurls .= ' ' . $res->base;
    my $tmp = (split /\./, $res->base->host)[-1];
    if ($tmp and $tmp =~ m|^\d+$|) {
        $tmp = 'arpa';
    }

    my ($tld) = $tmp;

    $ws->update(
        {
            redirect_count => $rcount,
            redirect_urls  => $rurls,
            ending_tld     => $tld
        }
    );
}
