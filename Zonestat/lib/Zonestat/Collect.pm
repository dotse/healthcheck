package Zonestat::Collect;

use 5.008008;
use strict;
use warnings;

use base 'Zonestat::Common';

use DNSCheck;
use Time::HiRes qw[time];
use POSIX qw[:signal_h];
use JSON;
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

my $debug = 0;
my $dns   = DNSCheck->new->dns;

our %server_regexps = (
    qr|^Apache/?(\S+)?|                   => 'Apache',
    qr|^Microsoft-IIS/(\S+)|              => 'Microsoft IIS',
    qr|^nginx/?(\S+)?|                    => 'nginx',
    qr|^Lotus-Domino|                     => 'Lotus Domino',
    qr|^GFE/(\S+)|                        => 'Google Web Server',
    qr|^lighttpd/?(\S+)?|                 => 'lighttpd',
    qr|^WebServerX|                       => 'WebServerX',
    qr|^Zope/\(Zope ([-a-zA-Z0-9.]+)|     => 'Zope',
    qr|^Resin/?(\S+)?|                    => 'Resin',
    qr|^Roxen.{0,2}(Challenger)?/?(\S+)?| => 'Roxen',
    qr|^ODERLAND|                         => 'Oderland',
    qr|WebSTAR/?(\S+)|                    => 'WebSTAR',
    qr|^IBM_HTTP_Server|                  => 'IBM HTTP Server (WebSphere)',
    qr|^Zeus/?(\S+)|                      => 'Zeus',
    qr|^Oversee Webserver v(\S+)|         => 'Oversee',
    qr|^Sun Java System Application Server (\S+)| =>
      'Sun Java System Application Server (GlassFish)',
    qr|^AkamaiGHost|                           => 'Akamai',
    qr|^Stronghold/?(\S+)|                     => 'RedHat Stronghold',
    qr|^Stoned Webserver (\S+)?|               => 'Stoned Webserver',
    qr|^Oracle HTTP Server Powered by Apache|  => 'Oracle HTTP Server',
    qr|^Oracle-Application-Server-10g/(\S+)|   => 'Oracle Application Server',
    qr|^TimmiT HTTPD Server powered by Apache| => 'TimmiT HTTPD Server',
    qr|^Sun-ONE-Web-Server/(\S+)?|             => 'Sun ONE',
    qr|^Server\d|                              => 'Oderland',
    qr|^mod-xslt/(\S+) Apache|                 => 'Apache (mod_xslt)',
    qr|^AppleIDiskServer-(\S+)|                => 'Apple iDisk',
    qr|^Microsoft-HTTPAPI/(\S+)|               => 'Microsoft HTTPAPI',
    qr|^Mongrel (\S+)|                         => 'Mongrel',
);

sub for_domain {
    my $self   = shift;
    my $domain = shift;
    my $dc     = DNSCheck->new;
    my %res    = (
        domain => $domain,
        start  => time(),
    );

    $dc->zone->test($domain);
    $res{dnscheck} = dnscheck_log_cleanup($dc->logger->export);

    my %hosts = extract_hosts($domain, $res{dnscheck});
    $hosts{webservers} = get_webservers($domain);
    $res{sslscan_mail} = $self->sslscan_mail($hosts{mailservers});
    $res{sslscan_web}  = $self->sslscan_web($domain);

    $res{pageanalyze} = $self->pageanalyze($domain);
    $res{webinfo}     = $self->webinfo($domain);

    $res{geoip} = $self->geoip(\%hosts);

    return \%res;
}

sub sslscan_mail {
    my $self  = shift;
    my $hosts = shift;
    my @res   = ();
    my $scan  = $self->cget(qw[zonestat sslscan]);

    return unless -x $scan;

    my $cmd = "$scan --starttls --xml=stdout --quiet ";
    foreach my $server (@$hosts) {
        push @res,
          {
            name => $server->{name},
            data =>
              XMLin(run_with_timeout(sub { qx[$cmd . $server->{name}] }, 600))
          };
    }

    return \@res;
}

sub sslscan_web {
    my $self   = shift;
    my $domain = shift;
    my $scan   = $self->cget(qw[zonestat sslscan]);
    my %res    = ();
    my $name   = "www.$domain";

    return \%res unless -x $scan;

    my $cmd = "$scan --xml=stdout --quiet ";
    $res{name} = $name;
    $res{data} = XMLin(run_with_timeout(sub { qx[$cmd . $name] }, 600));

    return \%res;
}

sub pageanalyze {
    my $self   = shift;
    my $domain = shift;
    my $padir  = $self->cget(qw[zonestat pageanalyzer]);
    my $python = $self->cget(qw[zonestat python]);
    my %res    = ();

    if ($padir and $python and -d $padir and -x $python) {
        foreach my $method (qw[http https]) {
            if (
                open my $pa, '-|',
                $python,     $padir . '/pageanalyzer.py',
                '-s',        '--nohex',
                '-t',        '300',
                '-f',        'json',
                "$method://www.$domain/"
              )
            {
                $res{$method} = decode_json(join('', <$pa>));
            }
        }
    }

    return \%res;
}

sub webinfo {
    my $self   = shift;
    my $domain = shift;
    my %res    = ();

    my $ua = LWP::UserAgent->new(max_size => 1024 * 1024, timeout => 30)
      ;    # Don't get more content than one megabyte
    $ua->agent('.SE Zonestat');

  DOMAIN:
    foreach
      my $u ('http://www.' . $domain . '/', 'https://www.' . $domain . '/')
    {
        my $https;
        my $ip;
        my $ssl;
        my $res;
        my $robots;

        if ($u =~ m|^http://www\.([^/]+)|) {
            $https = 0;
        } elsif ($u =~ m|^https://www\.([^/]+)|) {
            $https = 1;
        } else {
            print STDERR "Failed to parse: $u\n";
            next;
        }

        $ssl = _https_test('www.' . $domain) if $https;

        if ($https and (!defined($ssl) or (!$ssl->can('peer_certificate')))) {

            # We have an HTTPS URL, but can't establish an SSL connection. Skip.
            next DOMAIN;
        }

        $res    = $ua->get($u);
        $robots = check_robots_txt($u);

        my $rcount = scalar($res->redirects);
        my $rurls = join ' ', map { $_->base } $res->redirects;
        $rurls .= ' ' . $res->base;

        # Don't try to deal with anything but HTTP.
        next DOMAIN
          unless ($res->base->scheme eq 'http'
            or $res->base->scheme eq 'https');

        my ($tld) = $res->base->host =~ m|\.([-_0-9a-z]+)(:\d+)?$|i;

        if ($res->header('Client-Peer')) {

            # Works with LWP 5.836
            # Not guaranteed to work with later versions!
            $ip = $res->header('Client-Peer');
            $ip =~ s/:\d+$//;
        }

        my $issuer;

        if ($https and $ssl) {
            $issuer = $ssl->peer_certificate('issuer');
        }
        if (my $s = $res->header('Server')) {
            foreach my $r (keys %server_regexps) {
                if ($s =~ $r) {
                    my ($type, $encoding) =
                      content_type_from_header($res->header('Content-Type'));
                    $res{ $https ? 'https' : 'http' } = {
                        type          => $server_regexps{$r},
                        version       => $1,
                        raw_type      => $s,
                        https         => $https,
                        issuer        => $issuer,
                        url           => $u,
                        response_code => $res->code,
                        content_type  => $type,
                        charset       => $encoding,
                        content_length =>
                          scalar($res->header('Content-Length')),
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
        my ($type, $encoding) =
          content_type_from_header($res->header('Content-Type'));
        $res{ $https ? 'https' : 'http' } = {
            type           => 'Unknown',
            version        => undef,
            https          => $https,
            raw_type       => $res->header('Server'),
            url            => $u,
            response_code  => $res->code,
            content_type   => $type,
            charset        => $encoding,
            content_length => scalar($res->header('Content-Length')),
            redirect_count => $rcount,
            redirect_urls  => $rurls,
            ending_tld     => $tld,
            robots_txt     => $robots,
            ip             => $ip,
            issuer         => $issuer,
        };
    }

    return \%res;
}

sub geoip {
    my $self    = shift;
    my $hostref = shift;
    my $geoip   = Geo::IP->open($self->cget(qw[daemon geoip]));
    my @res     = ();

    foreach my $ns (@{ $hostref->{nameservers} }) {
        my $g = $geoip->record_by_addr($ns->{address});
        next unless defined($g);
        push @res,
          {
            address   => $ns->{address},
            type      => 'nameserver',
            country   => $g->country_name,
            code      => $g->country_code,
            city      => $g->city,
            longitude => $g->longitude,
            latitude  => $g->latitude,
            name      => $ns->{name},
          };
    }

    foreach my $mx (@{ $hostref->{mailservers} }) {
        foreach my $addr ($dns->find_addresses($mx->{name}, 'IN')) {
            my $g = $geoip->record_by_addr($addr);
            next unless defined($g);
            push @res,
              {
                address   => $addr,
                type      => 'mailserver',
                country   => $g->country_name,
                code      => $g->country_code,
                city      => $g->city,
                longitude => $g->longitude,
                latitude  => $g->latitude,
                name      => $mx->{name},
              };
        }
    }
    
    foreach my $ws (@{ $hostref->{webservers}}) {
        my $g = $geoip->record_by_addr($ws->{address});
        next unless defined($g);
        push @res,
          {
            address   => $ws->{address},
            type      => 'webserver',
            country   => $g->country_name,
            code      => $g->country_code,
            city      => $g->city,
            longitude => $g->longitude,
            latitude  => $g->latitude,
            name      => $ws->{name},
          };
    }

    return \@res;
}

###
### Assistance functions
###

sub dnscheck_log_cleanup {
    my @raw    = @{ shift(@_) };
    my @cooked = ();

    foreach my $r (@raw) {

        # Not all of these are used, but kept for documenting what data is what.
        my ($tstamp, $context, $level, $tag, $moduleid, $parentid, @args) = @$r;
        next if $level eq 'DEBUG' and !$debug;
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

    foreach my $r (@$dcref) {
        if ($r->{tag} eq 'DNS:NAMESERVER_FOUND') {
            next unless $r->{args}[0] eq $domain;
            push @{ $res{nameservers} },
              {
                domain  => $r->{args}[0],
                name    => $r->{args}[2],
                address => $r->{args}[3]
              };
        } elsif ($r->{tag} eq 'DNS:FIND_MX_RESULT') {
            foreach my $s (split(/,/, $r->{args}[1])) {
                next unless $r->{args}[0] eq $domain;
                push @{ $res{mailservers} },
                  { domain => $r->{args}[0], name => $s };
            }
        }
    }

    return %res;
}

sub run_with_timeout {
    my ($cref, $timeout) = @_;
    my $res = '';

    my $mask      = POSIX::SigSet->new(SIGALRM);
    my $action    = POSIX::SigAction->new(sub { die "timeout\n" }, $mask);
    my $oldaction = POSIX::SigAction->new;
    sigaction(SIGALRM, $action, $oldaction);
    eval {
        alarm($timeout);
        $res = $cref->();
        alarm(0);
    };
    sigaction(SIGALRM, $oldaction);
    return $res;
}

sub get_webservers {
    my $domain = shift;
    my @res;

    my $r = $dns->query_resolver("www.$domain", 'A', 'IN');
    if (defined($r) and $r->header->ancount > 0) {
        foreach my $rr ($r->answer) {
            next unless ($rr->type eq 'A' or $rr->type eq 'AAAA');
            push @res, { name => $rr->name, address => $rr->address };
        }
    }

    return \@res;
}

sub _https_test {
    my ($host) = @_;

    my $s = IO::Socket::INET->new(PeerAddr => $host, PeerPort => 443);

    if (!defined($s)) {
        return;
    }

    eval {
        $SIG{ALRM} = sub { die "timeout\n" };
        alarm(5);
        IO::Socket::SSL->start_SSL($s);
        alarm(0);
    };
    if ($@) {
        die unless $@ eq "timeout\n";
        return;
    }

    return $s;
}

sub check_robots_txt {
    my ($url) = @_;

    return !!get($url . 'robots.txt');
}

sub content_type_from_header {
    my @data = @_;
    my ($type, $encoding);

    foreach my $h (@data) {
        my ($t, $e) = $h =~ m|^(\w+/\w+)(?:;\s*charset\s*=\s*(\S+))?|;
        unless ($type) {
            $type = $t;
        }
        unless ($encoding) {
            $encoding = $e;
        }
        unless ($type or $encoding) {
            print STDERR "Failed to parse Content-Type header: $h\n";
        }

    }
    return ($type, $encoding);
}

1;
