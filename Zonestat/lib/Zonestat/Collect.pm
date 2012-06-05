package Zonestat::Collect;

use 5.008008;
use strict;
use utf8;
use warnings;

use base 'Zonestat::Common';

use Module::Find 'useall';

use DNSCheck;
use Time::HiRes qw[time];
use JSON::XS;
use XML::Simple;
use IO::Socket::INET;
use IO::Socket::INET6;
use IO::Socket::SSL;
use Geo::IP;
use Storable q[freeze];
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Request;
use POSIX qw[strftime :signal_h];
use Carp;
use Try::Tiny;
use Net::IP;
use Net::SMTP;
use IPC::Open3;
use Symbol 'gensym';
use IO::File;
use IO::Select;

our $debug = 0;
our $dc    = DNSCheck->new;
our $dns   = $dc->dns;
our $asn   = $dc->asn;

my @plugins = useall Zonestat::Collect;

our $VERSION = '0.1';

our %server_regexps = (
    qr|^Apache/?(\S+)?|                           => 'Apache',
    qr|^Microsoft-IIS/(\S+)|                      => 'Microsoft IIS',
    qr|^nginx/?(\S+)?|                            => 'nginx',
    qr|^Lotus-Domino|                             => 'Lotus Domino',
    qr|^GFE/(\S+)|                                => 'Google Web Server',
    qr|^lighttpd/?(\S+)?|                         => 'lighttpd',
    qr|^WebServerX|                               => 'WebServerX',
    qr|^Zope/\(Zope ([-a-zA-Z0-9.]+)|             => 'Zope',
    qr|^Resin/?(\S+)?|                            => 'Resin',
    qr|^Roxen.{0,2}(Challenger)?/?(\S+)?|         => 'Roxen',
    qr|^ODERLAND|                                 => 'Oderland',
    qr|WebSTAR/?(\S+)|                            => 'WebSTAR',
    qr|^IBM_HTTP_Server|                          => 'IBM HTTP Server (WebSphere)',
    qr|^Zeus/?(\S+)|                              => 'Zeus',
    qr|^Oversee Webserver v(\S+)|                 => 'Oversee',
    qr|^Sun Java System Application Server (\S+)| => 'Sun Java System Application Server (GlassFish)',
    qr|^AkamaiGHost|                              => 'Akamai',
    qr|^Stronghold/?(\S+)|                        => 'RedHat Stronghold',
    qr|^Stoned Webserver (\S+)?|                  => 'Stoned Webserver',
    qr|^Oracle HTTP Server Powered by Apache|     => 'Oracle HTTP Server',
    qr|^Oracle-Application-Server-10g/(\S+)|      => 'Oracle Application Server',
    qr|^TimmiT HTTPD Server powered by Apache|    => 'TimmiT HTTPD Server',
    qr|^Sun-ONE-Web-Server/(\S+)?|                => 'Sun ONE',
    qr|^Server\d|                                 => 'Oderland',
    qr|^mod-xslt/(\S+) Apache|                    => 'Apache (mod_xslt)',
    qr|^AppleIDiskServer-(\S+)|                   => 'Apple iDisk',
    qr|^Microsoft-HTTPAPI/(\S+)|                  => 'Microsoft HTTPAPI',
    qr|^Mongrel (\S+)|                            => 'Mongrel',
);

sub for_domain {
    my $self   = shift;
    my $domain = shift;
    my $dc     = DNSCheck->new;
    my %res    = (
        domain => $domain,
        start  => time(),
    );

    $dc->zone->test( $domain );


    $res{dnscheck} = dnscheck_log_cleanup( $dc->logger->export );

    my %hosts = extract_hosts( $domain, $res{dnscheck} );
    $hosts{webservers}  = get_webservers( $domain );
    $hosts{mailservers} = get_mailservers( $domain );
    $res{mailservers} = $self->mailserver_gather( $hosts{mailservers} );
    $res{sslscan_web} = $self->sslscan_web( $domain );
    $res{pageanalyze} = $self->pageanalyze( $domain );
    $res{webinfo} = $self->webinfo( $domain );
    $res{geoip} = $self->geoip( \%hosts );
    
    foreach my $p (@plugins) {
        my ($k, $v) = $p->collect($domain, $self);
        $res{$k} = $v;
    }
    
    $res{finish} = time();

    return \%res;
}

sub smtp_info_for_address {
    my $self = shift;
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
        my $tmp = $self->smtp_info_for_address( $server->{name} );
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
            $tmp->{evaluation} = sslscan_evaluate( $sslscan );
        }
        push @res, $tmp;
    }

    return \@res;
}

sub sslscan_web {
    my $self   = shift;
    my $domain = shift;
    my $scan   = $self->cget( qw[zonestat sslscan] );
    my %res    = ();
    my $name   = "www.$domain";

    return \%res unless ($scan and -x $scan);

    my $cmd = "$scan --xml=stdout --quiet --no-failed";
    $res{name} = $name;
    my ( $success, $stdout, $stderr ) = run_external( 600, $cmd . ' ' . $name );
    try {
        $res{data} = XMLin( $stdout );
    };
    if ( $stderr and $debug ) {    # sslscan prints lots of garbage on STDERR.
        print STDERR "[$$] $cmd: $stderr\n";
    }

    $res{evaluation} = sslscan_evaluate( $res{data} );
    $res{known_ca}   = $self->https_known_ca( $domain );

    return \%res;
}

sub pageanalyze {
    my $self   = shift;
    my $domain = shift;
    my $padir  = $self->cget( qw[zonestat pageanalyzer] );
    my $python = $self->cget( qw[zonestat python] );
    my %res    = ();

    if ( $padir and $python and -d $padir and -x $python ) {
        foreach my $method ( qw[http https] ) {
            my ( $success, $stdout, $stderr ) = run_external( 600, $python, $padir . '/pageanalyzer.py', '-s', '--nohex', '-t', '300', '-f', 'json', "$method://www.$domain/" );
            if ( $success and $stdout ) {
                $res{$method} = decode_json( $stdout );
                delete $res{$method}{resources};
            }
            if ( $debug and $stderr ) {
                print STDERR $stderr;
            }
        }
    }

    return \%res;
}

sub webinfo {
    my $self   = shift;
    my $domain = shift;
    my %res    = ();

    my $ua = LWP::UserAgent->new( max_size => 1024 * 1024, timeout => 30 );    # Don't get more content than one megabyte
    $ua->agent( '.SE Zonestat' );

  DOMAIN:
    foreach my $u ( 'http://www.' . $domain . '/', 'https://www.' . $domain . '/' ) {
        my $https;
        my $ip;
        my $ssl;
        my $res;
        my $robots;

        if ( $u =~ m|^http://www\.([^/]+)| ) {
            $https = 0;
        }
        elsif ( $u =~ m|^https://www\.([^/]+)| ) {
            $https = 1;
        }
        else {
            print STDERR "Failed to parse: $u\n";
            next;
        }

        $ssl = _https_test( 'www.' . $domain ) if $https;

        if ( $https && ( !defined( $ssl ) || ( !$ssl->can( 'peer_certificate' ) ) ) ) {

            # We have an HTTPS URL, but can't establish an SSL connection. Skip.
            next DOMAIN;
        }

        $res    = $ua->get( $u );
        $robots = check_robots_txt( $u );

        my $rcount = scalar( $res->redirects );
        my $rurls = join ' ', map { $_->base } $res->redirects;
        $rurls .= ' ' . $res->base;

        # Don't try to deal with anything but HTTP.
        next DOMAIN
          unless ( $res->base->scheme eq 'http'
            or $res->base->scheme eq 'https' );

        my ( $tld ) = $res->base->host =~ m|\.([-_0-9a-z]+)(:\d+)?$|i;

        if ( $res->header( 'Client-Peer' ) ) {

            # Works with LWP 5.836
            # Not guaranteed to work with later versions!
            $ip = $res->header( 'Client-Peer' );
            $ip =~ s/:\d+$//;
        }

        my $issuer;

        if ( $https and $ssl ) {
            $issuer = $ssl->peer_certificate( 'issuer' );
        }
        if ( my $s = $res->header( 'Server' ) ) {
            foreach my $r ( keys %server_regexps ) {
                if ( $s =~ $r ) {
                    my ( $type, $encoding ) = content_type_from_header( $res->header( 'Content-Type' ) );
                    $res{ $https ? 'https' : 'http' } = {
                        type           => $server_regexps{$r},
                        version        => $1,
                        raw_type       => $s,
                        https          => $https,
                        issuer         => $issuer,
                        url            => $u,
                        response_code  => ( '' . $res->code ),
                        content_type   => $type,
                        charset        => $encoding,
                        content_length => scalar( $res->header( 'Content-Length' ) ),
                        redirect_count => $rcount,
                        redirect_urls  => $rurls,
                        ending_tld     => $tld,
                        robots_txt     => $robots,
                        ip             => $ip,
                    };

                    next DOMAIN;
                }
            }
        }
        my ( $type, $encoding ) = content_type_from_header( $res->header( 'Content-Type' ) );
        my %tmp;
        $tmp{type}           = 'Unknown';
        $tmp{version}        = undef;
        $tmp{https}          = $https;
        $tmp{raw_type}       = $res->header( 'Server' );
        $tmp{url}            = $u;
        $tmp{response_code}  = $res->code;
        $tmp{content_type}   = $type;
        $tmp{charset}        = $encoding;
        $tmp{content_length} = scalar( $res->header( 'Content-Length' ) );
        $tmp{redirect_count} = $rcount;
        $tmp{redirect_urls}  = $rurls;
        $tmp{ending_tld}     = $tld;
        $tmp{robots_txt}     = $robots;
        $tmp{ip}             = $ip;
        $tmp{issuer}         = $issuer;
        $res{ $https ? 'https' : 'http' } = \%tmp;
    }

    return \%res;
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

###
### Assistance functions
###

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

# Runs an external command, with a timeout, and collecting both stdout and stderr from it.
sub run_external {
    my ( $timeout, @args ) = @_;
    my ( $read, $err );
    $err = gensym();
    my %output;
    my $pid     = open3( undef, $read, $err, '-' );
    my $read_no = $read->fileno;
    my $err_no  = $err->fileno;

    if ( $pid ) {    # Parent
        local $SIG{ALRM} = sub { die 'timeout' };
        alarm( $timeout );
        eval {
            my $s = IO::Select->new( $read, $err );
            while ( $s->handles ) {
                foreach my $h ( $s->can_read ) {
                    if ( my $line = $h->getline ) {
                        $output{ $h->fileno } .= $line;
                    }
                    else {
                        $s->remove( $h );
                    }
                }
            }
        };
        if ( $@ and $@ =~ /^timeout/ ) {
            kill 15, $pid;
            return ( undef, '', '' );
        }
        else {
            alarm( 0 );
        }
    }
    else {    # Child
        exec( @args );
    }

    return ( 1, $output{ $read->fileno }, $output{ $err->fileno } );
}

sub get_mailservers {
    my $domain = shift;
    my @res;

    my $r = $dns->query_resolver( $domain, 'MX', 'IN' );
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

    my $r = $dns->query_resolver( "www.$domain", 'A', 'IN' );
    if ( defined( $r ) and $r->header->ancount > 0 ) {
        foreach my $rr ( $r->answer ) {
            next unless ( $rr->type eq 'A' or $rr->type eq 'AAAA' );
            push @res, { name => $rr->name, address => $rr->address };
        }
    }

    return \@res;
}

sub _https_test {
    my ( $host ) = @_;

    my $s = IO::Socket::INET->new( PeerAddr => $host, PeerPort => 443 );

    if ( !defined( $s ) ) {
        return;
    }

    ## no critic (Variables::RequireLocalizedPunctuationVars)
    # No, Critic, %SIG should not be localized. Ever. That's not how signals work.
    eval {
        $SIG{ALRM} = sub { die "timeout\n" };
        alarm( 5 );
        IO::Socket::SSL->start_SSL( $s );
        alarm( 0 );
    };
    if ( $@ ) {
        die unless $@ eq "timeout\n";
        return;
    }

    return $s;
}

sub check_robots_txt {
    my ( $url ) = @_;

    return !!get( $url . 'robots.txt' );
}

sub content_type_from_header {
    my @data = @_;
    my ( $type, $encoding );

    foreach my $h ( @data ) {
        my ( $t, $e ) = $h =~ m|^([^/]+/[-\w]+)(?:;\s*charset\s*=\s*(\S+))?|;
        unless ( $type ) {
            $type = $t;
        }
        unless ( $encoding ) {
            $encoding = $e;
        }
        unless ( $type or $encoding ) {
            print STDERR "Failed to parse Content-Type header: $h\n";
        }

    }

    if ( $encoding ) {
        $encoding = lc( $encoding );
        $encoding =~ s/^utf[^-]/utf-/;
    }

    return ( $type, $encoding );
}

## no critic (TestingAndDebugging::ProhibitNoWarnings)
sub sslscan_evaluate {
    no warnings 'uninitialized';
    my $data = shift;
    $data = $data->{ssltest};
    my %result;

    # Check renegotiation status.
    if ( $data->{renegotiation}{secure} and $data->{renegotiation}{supported} ) {
        $result{renegotiation} = 'secure';
    }
    elsif ( $data->{renegotiation}{supported} ) {
        $result{renegotiation} = 'insecure';
    }
    else {
        $result{renegotiation} = 'none';
    }

    my @default = ();
    if ( defined( $data->{defaultcipher} )
        and ref( $data->{defaultcipher} ) eq 'ARRAY' )
    {
        @default = @{ $data->{defaultcipher} };
    }
    elsif ( defined( $data->{defaultcipher} )
        and ref( $data->{defaultcipher} ) eq 'HASH' )
    {
        @default = ( $data->{defaultcipher} );
    }

    # Check support for HTTPS
    $result{https_support} = ( @default > 0 );

    # Check support for SSL versions
    $result{sslv2} = !!( grep { $_->{sslversion} eq 'SSLv2' } @default );
    $result{sslv3} = !!( grep { $_->{sslversion} eq 'SSLv3' } @default );
    $result{tlsv1} = !!( grep { $_->{sslversion} eq 'TLSv1' } @default );

    # We're going to traverse this list a few times.
    my @cipher;
    if ( defined( $data->{cipher} ) and ref( $data->{cipher} ) eq 'ARRAY' ) {
        @cipher = @{ $data->{cipher} };
    }
    elsif ( defined( $data->{cipher} ) and ref( $data->{cipher} ) eq 'HASH' ) {
        @cipher = ( $data->{cipher} );
    }
    @cipher = grep { $_->{status} eq 'accepted' } @cipher;

    # Is authentication without key permitted?
    $result{no_key_auth} = !!( grep { $_->{au} eq 'None' } @cipher );

    $result{no_encryption}     = !!( grep { $_->{bits} == 0 } @cipher );
    $result{weak_encryption}   = !!( grep { $_->{bits} < 128 } @cipher );
    $result{medium_encryption} = !!( grep { $_->{bits} >= 128 and $_->{bits} < 256 } @cipher );
    $result{strong_encryption} = !!( grep { $_->{bits} >= 256 } @cipher );

    # This relies on the special EV OID _not_ getting translated to a name.
    $result{ev_cert} = !!( index( $data->{certificate}{subject}, '1.3.6.1.4.1.311.60.2.1.3' ) >= 0 );

    return \%result;
}

sub https_known_ca {
    my $self   = shift;
    my $server = shift;

    my $openssl  = $self->cget( qw[zonestat openssl] );
    my $certfile = $self->cget( qw[zonestat cacertfile] );

    unless ( $openssl and $certfile ) {
        return;
    }

    unless ( -x $openssl and -r $certfile ) {
        confess "$openssl not executable or $certfile not readable";
    }

    my $raw = qx[$openssl s_client -CAfile $certfile -connect www.$server:443 < /dev/null 2>/dev/null];

    if ( $raw =~ m|Verify return code: \d+ \(([^)]+)\)| ) {
        my $verdict = $1;
        if ( $verdict eq 'ok' ) {
            return { ok => 1, verdict => $verdict };
        }
        else {
            return { ok => 0, verdict => $verdict };
        }
    }
    else {
        return { ok => undef, verdict => undef };
    }
}

# This methods is too slow to be useful, and only included here if we ever
# want to use it for some special purpose.
## no critic (Modules::RequireExplicitInclusion)
# No, we should not include Net::DNS::Resolver ourselves, that's not how it works.
sub kaminsky_check {
    my $self = shift;
    my $addr = shift;

    # https://www.dns-oarc.net/oarc/services/porttest
    my $res = Net::DNS::Resolver->new(
        nameservers => [$addr],
        recurse     => 1,
    );
    my $p = $res->query( 'porttest.dns-oarc.net', 'IN', 'TXT', $addr );

    if ( defined( $p ) and $p->header->ancount > 0 ) {
        my $r = ( grep { $_->type eq 'TXT' } $p->answer )[0];
        if ( $r ) {
            my ( $verdict ) = $r->txtdata =~ m/ is ([A-Z]+):/;
            $verdict ||= 'UNKNOWN';
            return $verdict;
        }
    }

    return "UNKNOWN";
}

1;

=head1 NAME

Zonestat::Collect - Module that collects data about a domain and returns it as a reference to a nested hash.

=head1 SYNOPSIS

 my $href = Zonestat->new->collect->for_domain("example.org")
 
=head1 DESCRIPTION

The hashref returned from the C<for_domain> method contains a number of sections. They look as follows.

=over
 
=item dnscheck

Under this key is a cleaned-up version of the exported log output from
L<DNSCheck>. It's a reference to a list containing references to hashes for
log entries. Each hash has the keys C<timestamp>, C<level>, C<tag> and
C<args>. The first three are simply the respective values from DNSCheck, the
last is a reference to a list with the arguments for the tag.

=item dkim

Under this key is a hash with three keys. The first is C<dkim>, which holds
data from the domain's _adsp._domainkey resource records, if one exists. The
second is C<spf_real>, which holds data from the domain's SPF record, if one
exists. And the final one is C<spf_transitionary>, which is the contents of an
SPF-formatted TXT record, if one exists.

=item whatweb

Under this key output from WhatWeb is stored. It's not further used at this
time.

=item mailservers

This is a list of hashes, each one holding data for a server pointed to by an
MX record for the domain. In these hashes are keys C<name> with the DNS name
for it, C<banner> with the SMTP banner message it gave and C<starttls> which
has the value 1 if the server announced STARTTLS capability and 0 otherwise.
If C<starttls> is true, it also has the keys C<sslscan> holding the results
from an sslscan run on the server (see entry below for format of that data)
and a key C<evaluation> with a brief evaluation of that data.

=item sslscan_web

This is a reference to a hash with three keys. The first is C<name>, and holds
the DNS name for the scanned server. The second is C<data> and holds a hash
that is a literal translation of the XML output from the L<sslscan> program
ran with the gathered domain's "www." name at port 443. The third key is
C<evaluation>, and is a hash with a brief evaluation of the cryptographic
quality of the scanned SSL server.

=item pageanalyze

This is a reference to a hash with two keys, C<http> and C<https>. They
contain the results from running L<pageanalyzer> at the domain's "www." name
with the respective protocols. The results are hashes with a literal
translation of the output from L<pageanalyzer>'s JSON mode.

=item webinfo

Like the previous key, this is a reference to a hash with C<http> and C<https>
keys. Each of those are also references to hashes, with the following keys.

=over

=item type

A short string describing the webserver software, detected by running a set of
regexps on the HTTP response Server header field. If none of the regexps
matched, this field will be C<Unknown> and the following one undefined.

=item version

The version of the webserver software, also extracted from the Server header field.

=item raw_type

The unprocessed content of the Server header field.

=item https

A boolean value indicating if the information was gathered over HTTPS or not.

=item url

The URL the information was gathered from.

=item response_code

The HTTP response code received.

=item content_type

The MIME type the server claimed the content is.

=item charset

If the content was of a type with a sub-specified character encoding, this is
the name of the encoding. Note that this is nothing but what the server
claimed, and need not be anything resembling the name of a proper character
encoding!

=item content_length

The value of the C<Content-Length> header field. 

=item redirect_count

The number of times the HTTP library followed redirects before it finally got
a response.

=item redirect_urls

A list of the URLs in the chain of redirects.

=item ending_tld

The top-level domain of the host part in the URL of the final step of the
redirect chain.

=item robots_txt

A boolean value indicting if this server returned something for the path
C</robots.txt>.

=item ip

The IP address that the content was finally fetched from, if that information
was recorded by the L<LWP::UserAgent> object in a form this code understands.
This may not work with future versions of L<LWP>.

=item issuer

The issuer field of the server SSL certificate, for HTTPS connections.

=back

=item geoip

This is a reference to a list of hashes, each giving GeoIP information about a
particular server. The hashes have the following keys.

=over

=item address

The IP address that was looked up.

=item asn

A list of ASN numbers in which the address above is announced.

=item type

The type of the server. Can be one of C<nameserver>, C<mailserver> or C<webserver>.

=item country

The name of the country.

=item code

The two-letter ISO code for the country.

=item city

The name of the city.

=item longitude

The longitude of the IP address' location.

=item latitude

Its latitude.

=item name

The server's name.

=back

=back

