package Zonestat::Collect::DNSCheck;

use strict;
use warnings;
use utf8;

use Zonestat::Util;
use XML::Simple;
use Time::HiRes 'time';
use Geo::IP;
use Net::IP;
use Net::SMTP;
use Try::Tiny;

our $debug = $Zonestat::Collect::debug;
our $dc    = dnscheck;
our $dns   = $dc->dns;
our $asn   = $dc->asn;

sub collect {
    my ($self, $domain, $parent) = @_;
    my %res;
    my $dc     = dnscheck();
    
    $dc->zone->test( $domain );
    $res{dnscheck} = dnscheck_log_cleanup( $dc->logger->export );

    my %hosts = extract_hosts( $domain, $res{dnscheck} );
    $hosts{webservers}  = get_webservers( $domain );
    $hosts{mailservers} = get_mailservers( $domain );

    $res{mailservers} = mailserver_gather( $parent, $hosts{mailservers} );
    $res{geoip} = geoip( $parent, \%hosts );

    return (
        dnscheck => $res{dnscheck},
        mailservers => $res{mailservers},
        geoip => $res{geoip},
    );
}

sub dnscheck_log_cleanup {
    my ( $aref ) = @_;
    my @raw      = @{$aref};
    my @cooked   = ();

    foreach my $r ( @raw ) {

        # Not all of these are used, but kept for documenting what data is what.
        my ( $tstamp, $context, $level, $tag, $moduleid, $parentid, @args ) = @$r;
        next if $level eq 'DEBUG' and ( not $debug );
        next if $tag =~ m/:(BEGIN|END)$/;

        push @cooked,
          {
            timestamp => $tstamp,
            level     => $level,
            tag       => $tag,
            args      => \@args,
          };
    }

    return \@cooked;
}

sub extract_hosts {
    my $domain = shift;
    my $dcref  = shift;
    my %res;
    my %asn;

    foreach my $r ( @$dcref ) {
        if ( $r->{tag} eq 'DNS:NAMESERVER_FOUND' ) {
            next unless $r->{args}[0] eq $domain;
            push @{ $res{nameservers} },
              {
                domain  => $r->{args}[0],
                name    => $r->{args}[2],
                address => $r->{args}[3],
                asn     => $asn->lookup( $r->{args}[3] ),
              };
        }
    }

    return %res;
}

sub get_mailservers {
    my $domain = shift;
    my @res;

    my $r = $dns->query_resolver( $domain, 'IN', 'MX' );

    if ( defined( $r ) and $r->header->ancount > 0 ) {
        foreach my $rr ( $r->answer ) {
            next unless $rr->type eq 'MX';
            foreach my $addr ( $dns->find_addresses( $rr->exchange, 'IN' ) ) {
                push @res, { name => $rr->exchange, address => $addr };
            }
        }
    }

    return \@res;
}

sub get_webservers {
    my $domain = shift;
    my @res;

    my $r = $dns->query_resolver( "www.$domain", 'IN', 'A' );

    if ( defined( $r ) and $r->header->ancount > 0 ) {
        foreach my $rr ( $r->answer ) {
            next unless ( $rr->type eq 'A' or $rr->type eq 'AAAA' );
            push @res, { name => $rr->name, address => $rr->address };
        }
    }

    return \@res;
}

sub smtp_info_for_address {
    my $addr = shift;

    my $starttls = 0;
    my $banner;
    my $ip;

    my $smtp = Net::SMTP->new( $addr );
    if ( defined( $smtp ) ) {
        $starttls = 1 if $smtp->message =~ m|STARTTLS|;
        $banner   = $smtp->banner;
        $ip       = $smtp->peerhost;
    }

    return {
        starttls => $starttls,
        banner   => $banner,
        ip       => $ip,
    };
}

sub mailserver_gather {
    my $self  = shift;
    my $hosts = shift;
    my @res   = ();
    my $scan  = $self->cget( qw[zonestat sslscan] );

    foreach my $server ( @$hosts ) {
        my $tmp = smtp_info_for_address( $server->{name} );
        $tmp->{name} = $server->{name};
        if ( $tmp->{starttls} and $scan and -x $scan) {
            my $sslscan;
            my $cmd = "$scan --starttls --xml=stdout --quiet --no-failed";
            my ( $success, $stdout, $stderr ) = run_external( 600, $cmd . ' ' . $server->{name} );
            try {
                $sslscan = XMLin( $stdout );
            };
            if ( $stderr ) {
                print STDERR "[$$] $cmd: $stderr\n" if $debug;
            }

            $tmp->{sslscan}    = $sslscan;
            $tmp->{evaluation} = Zonestat::Collect::Sslscan::sslscan_evaluate( $sslscan );
        }
        push @res, $tmp;
    }

    return \@res;
}

sub geoip {
    my $self    = shift;
    my $hostref = shift;
    my $geoip   = Geo::IP->open( $self->cget( qw[daemon geoip] ) );
    my @res     = ();

    foreach my $ns ( @{ $hostref->{nameservers} } ) {
        my $g  = $geoip->record_by_addr( $ns->{address} );
        my $ip = Net::IP->new( $ns->{address} );
        my $ipversion;
        $ipversion = $ip->version if defined( $ip );
        if ( $g ) {
            push @res,
              {
                address   => $ns->{address},
                ipversion => $ipversion,
                asn       => $asn->lookup( $ns->{address} ),
                type      => 'nameserver',
                country   => $g->country_name,
                code      => $g->country_code,
                city      => $g->city,
                longitude => $g->longitude,
                latitude  => $g->latitude,
                name      => $ns->{name},
              };
        }
        else {
            push @res,
              {
                address   => $ns->{address},
                ipversion => $ipversion,
                asn       => $asn->lookup( $ns->{address} ),
                type      => 'nameserver',
                country   => undef,
                code      => undef,
                city      => undef,
                longitude => undef,
                latitude  => undef,
                name      => $ns->{name},
              };
        }
    }

    foreach my $mx ( @{ $hostref->{mailservers} } ) {
        foreach my $addr ( $dns->find_addresses( $mx->{name}, 'IN' ) ) {
            my $g  = $geoip->record_by_addr( $addr );
            my $ip = Net::IP->new( $addr );
            my $ipversion;
            $ipversion = $ip->version if defined( $ip );
            if ( $g ) {
                push @res,
                  {
                    address   => $addr,
                    ipversion => $ipversion,
                    asn       => $asn->lookup( $addr ),
                    type      => 'mailserver',
                    country   => $g->country_name,
                    code      => $g->country_code,
                    city      => $g->city,
                    longitude => $g->longitude,
                    latitude  => $g->latitude,
                    name      => $mx->{name},
                  };
            }
            else {
                push @res,
                  {
                    address   => $addr,
                    ipversion => $ipversion,
                    asn       => $asn->lookup( $addr ),
                    type      => 'mailserver',
                    country   => undef,
                    code      => undef,
                    city      => undef,
                    longitude => undef,
                    latitude  => undef,
                    name      => $mx->{name},
                  };
            }
        }
    }

    foreach my $ws ( @{ $hostref->{webservers} } ) {
        my $g  = $geoip->record_by_addr( $ws->{address} );
        my $ip = Net::IP->new( $ws->{address} );
        my $ipversion;
        $ipversion = $ip->version if defined( $ip );
        if ( $g ) {
            push @res,
              {
                address   => $ws->{address},
                ipversion => $ipversion,
                asn       => $asn->lookup( $ws->{address} ),
                type      => 'webserver',
                country   => $g->country_name,
                code      => $g->country_code,
                city      => $g->city,
                longitude => $g->longitude,
                latitude  => $g->latitude,
                name      => $ws->{name},
              };
        }
        else {
            push @res,
              {
                address   => $ws->{address},
                ipversion => $ipversion,
                asn       => $asn->lookup( $ws->{address} ),
                type      => 'webserver',
                country   => undef,
                code      => undef,
                city      => undef,
                longitude => undef,
                latitude  => undef,
                name      => $ws->{name},
              };
        }
    }

    return \@res;
}

1;