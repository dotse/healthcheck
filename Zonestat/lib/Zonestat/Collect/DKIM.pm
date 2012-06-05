package Zonestat::Collect::DKIM;

use base 'Zonestat::Collect';

our $debug = $Zonestat::Collect::debug;
our $dc    = $Zonestat::Collect::dc;
our $dns   = $Zonestat::Collect::dns;
our $asn   = $Zonestat::Collect::asn;

sub collect {
    my ($self, $domain) = @_;
    
    return ('dkim', dkim_data($domain));
}

sub dkim_data {
    my $domain = shift;

    my $adsp;
    my $spf_spf;
    my $spf_txt;

    # DKIM/ADSP
    my $packet = $dns->query_resolver( '_adsp._domainkey.' . $domain, 'IN', 'TXT' );

    if ( defined( $packet ) and $packet->header->ancount > 0 ) {
        my $rr = ( $packet->answer )[0];
        if ( $rr->type eq 'TXT' ) {
            $adsp = $rr->txtdata;
        }
    }

    # SPF, "real" kind
    $packet = $dns->query_resolver( $domain, 'IN', 'SPF' );
    if ( defined( $packet ) and $packet->header->ancount > 0 ) {
        my $rr = ( grep { $_->type eq 'SPF' } $packet->answer )[0];
        if ( $rr ) {
            $spf_spf = $rr->txtdata;
        }
    }

    # SPF, transitionary kind
    $packet = $dns->query_resolver( $domain, 'IN', 'TXT' );
    if ( defined( $packet ) and $packet->header->ancount > 0 ) {
        my $rr = ( grep { $_->type eq 'TXT' } $packet->answer )[0];
        if ( $rr and $rr->txtdata =~ /^v=spf/ ) {
            $spf_txt = $rr->txtdata;
        }
    }

    return {
        adsp              => $adsp,
        spf_real          => $spf_spf,
        spf_transitionary => $spf_txt,
    };
}

1;