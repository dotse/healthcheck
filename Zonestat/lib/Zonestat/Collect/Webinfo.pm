package Zonestat::Collect::Webinfo;

use strict;
use warnings;

use Zonestat::Util;
use LWP::UserAgent;
use LWP::Simple;
use HTTP::Request;
use IO::Socket::INET;
use IO::Socket::SSL;

our $debug = $Zonestat::Collect::debug;

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

sub collect {
    my ($self, $domain, $parent) = @_;
    
    return ('webinfo', webinfo($parent, $domain));
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

        # Store headers in raw form
        my $headers_aref = [];
        $res->headers->scan( sub {
            my ($name, $content) = @_;
            push @{$headers_aref}, [$name, $content];
        } );

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
                        headers        => $headers_aref,
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
        $tmp{headers}        = $headers_aref;

        $res{ $https ? 'https' : 'http' } = \%tmp;
    }

    return \%res;
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

1;