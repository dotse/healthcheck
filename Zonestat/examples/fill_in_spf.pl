#!/opt/local/bin/perl

use warnings;
use strict;

use Zonestat;

my $zs  = Zonestat->new->present;
my $dns = DNSCheck->new->dns;

foreach my $tr ($zs->dbx('Testrun')->search({})->all) {
    foreach my $ms ($tr->mailservers->all) {
        unless ($ms->spf_spf or $ms->spf_txt) {
            print 'Gathering SPF records for ' . $ms->domain->domain . "\n";
            my ($packet, $spf_spf, $spf_txt);

            # SPF, "real" kind
            $packet = $dns->query_resolver($ms->domain->domain, 'IN', 'SPF');
            if (defined($packet) and $packet->header->ancount > 0) {
                my $rr = (grep { $_->type eq 'SPF' } $packet->answer)[0];
                if ($rr) {
                    $spf_spf = $rr->txtdata;
                }
            }

            # SPF, transitionary kind
            $packet = $dns->query_resolver($ms->domain->domain, 'IN', 'TXT');
            if (defined($packet) and $packet->header->ancount > 0) {
                my $rr = (grep { $_->type eq 'TXT' } $packet->answer)[0];
                if ($rr and $rr->txtdata =~ /^v=spf/) {
                    $spf_txt = $rr->txtdata;
                }
            }

            $ms->update({ spf_spf => $spf_spf, spf_txt => $spf_txt });
        }
    }
}
