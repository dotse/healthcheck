package Zonestat::Gather;

use 5.008008;
use strict;
use warnings;

use DNSCheck;

use base 'Zonestat::Common';

use LWP::Parallel::UserAgent;
use HTTP::Request;
use IO::Socket::SSL;
use Carp;
use POSIX qw[strftime];
use Geo::IP;
use Net::IP;
use Net::SMTP;

our $VERSION = '0.01';
our $debug   = 0;
STDOUT->autoflush(1) if $debug;

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

sub enqueue_domainset {
    my $self = shift;
    my $ds   = shift;
    my $name = shift || strftime('%g%m%d %H:%M', localtime());

    my $run = $ds->add_to_testruns({ name => $name });
    my $dbh = $self->dbh;

   # We use a direct DBI call here, since not having to bring the data up from
   # the database and then back into it again speeds things up by several orders
   # of magnitude.
    $dbh->do(
        'INSERT INTO queue (domain, priority, source_id, source_data)
         SELECT domains.domain, 4, ?, ? FROM domains, domain_set_glue
         WHERE domain_set_glue.set_id = ? AND domains.id = domain_set_glue.domain_id',
        undef,
        $self->source_id,
        $run->id,
        $ds->id
    );
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

sub get_server_data {
    my $self = shift;
    my ($trid, $domainname) = @_;

    my $tr = $self->dbx('Testrun')->find($trid);
    my $domain =
      $self->dbx('Domains')->search({ domain => $domainname })->first;

    print "Gathering for " . $domain->domain . " in testrun " . $tr->name . "\n"
      if $debug;
    $self->get_http_server_data($tr->id, $domain->domain);
    $self->collect_geoip_information_for_server($tr, $domain);
}

sub get_http_server_data {
    my $self    = shift;
    my $tr_id   = shift;
    my @domains = @_;
    my $db      = $self->dbx('Domains');
    my %urls    = map { ($_, 'http://www.' . $_) } @domains;

    my $tr = $self->dbx('Testrun')->find($tr_id);

    while (@domains) {
        my $ua = LWP::Parallel::UserAgent->new(max_size => 1024 * 1024)
          ;    # Don't get more content than one megabyte
        $ua->redirect(0);
        $ua->max_hosts(50);
        $ua->timeout(10);
        $ua->agent('.SE Zonestat');

        foreach my $u (splice(@domains, 0, 25)) {
            $ua->register(HTTP::Request->new(GET => 'http://www.' . $u));
            $ua->register(HTTP::Request->new(GET => 'https://www.' . $u));
        }

        my $rr = $ua->wait;

      DOMAIN:
        foreach my $k (keys %$rr) {
            my $res = $rr->{$k}->response;
            my $url = $res->request->url;
            my $dom;
            my $https;
            my $ip;

            if ($url =~ m|^http://www\.([^/]+)|) {
                $dom   = $1;
                $https = 0;
            } elsif ($url =~ m|^https://www\.([^/]+)|) {
                $dom   = $1;
                $https = 1;
            } else {
                print STDERR "Failed to parse: $url\n";
                next;
            }

            unless ($urls{$dom}) {
                die "Response for domain not queried: $dom\n";
            }

            my $ddb = $db->search({ domain => $dom })->first;
            unless (defined($ddb)) {
                carp "Failed to find domain: $dom";
                next DOMAIN;
            }

            if ($res->header('Client-Peer')) {
                $ip = ((split(/:/, $res->header('Client-Peer')))[0]);
            }

            my $issuer;

            if (my $s = $res->header('Server')) {
                if (
                    $https
                    and my $s = IO::Socket::SSL->new(
                        PeerAddr => 'www.' . $dom,
                        PeerPort => 443
                    )
                  )
                {
                    $issuer = $s->peer_certificate('issuer');
                }

                foreach my $r (keys %server_regexps) {
                    if ($s =~ $r) {
                        my ($type, $encoding) = content_type_from_header(
                            $res->header('Content-Type'));
                        my $obj = $ddb->add_to_webservers(
                            {
                                type          => $server_regexps{$r},
                                version       => $1,
                                raw_type      => $s,
                                https         => $https,
                                issuer        => $issuer,
                                raw_response  => $res,
                                testrun_id    => $tr->id,
                                url           => $url,
                                response_code => $res->code,
                                content_type  => $type,
                                charset       => $encoding,
                                content_length =>
                                  scalar($res->header('Content-Length')),
                            }
                        );
                        $obj->update({ ip => $ip }) if defined($ip);
                        next DOMAIN;
                    }
                }
                my ($type, $encoding) =
                  content_type_from_header($res->header('Content-Type'));
                my $obj = $ddb->add_to_webservers(
                    {
                        type          => 'Unknown',
                        raw_type      => $s,
                        raw_response  => $res,
                        testrun_id    => $tr->id,
                        url           => $url,
                        response_code => $res->code,
                        content_type  => $type,
                        charset       => $encoding,
                        content_length =>
                          scalar($res->header('Content-Length')),
                    }
                );
                $obj->update({ ip => $ip }) if defined($ip);
            }
        }
    }
}

sub rescan_unknown_servers {
    my $self = shift;
    my $db = $self->dbx('Webserver')->search({ type => 'Unknown' });

  DOMAIN:
    while (my $row = $db->next) {
        my $str = $row->raw_type;
        foreach my $r (keys %server_regexps) {
            if ($str =~ $r) {
                print "Updating to "
                  . $server_regexps{$r} . ": "
                  . $row->raw_response . "\n"
                  if $debug;
                $row->update(
                    {
                        type    => $server_regexps{$r},
                        version => $1
                    }
                );
            }
        }
    }
}

sub lookup_asn_from_results {
    my ($ip, $tr, $domain) = @_;

    $ip = Net::IP->new($ip)->ip;

    my $res =
      $tr->search_related('tests', { domain => $domain })
      ->search_related('results',
        { message => 'CONNECTIVITY:ANNOUNCED_BY_ASN', arg0 => $ip })->first;

    if (defined($res) and $res->arg1) {
        return $res->arg1;
    }

    $res =
      $tr->search_related('tests', { domain => $domain })
      ->search_related('results',
        { message => 'CONNECTIVITY:V6_ANNOUNCED_BY_ASN', arg0 => $ip })->first;

    if (defined($res)) {
        return $res->arg1;
    } else {
        return;
    }
}

sub collect_smtp_information {
    my $self = shift;
    my ($tr, $domain, $addr, $name) = @_;
    my $ms = $self->dbx('Mailserver');

    my $adsp;
    my $starttls = 0;
    my $banner;

    my $ip = Net::IP->new($addr);
    croak "Malformed IP address: $addr" unless defined($ip);

    my $dns = DNSCheck->new->dns;
    my $packet =
      $dns->query_resolver('_adsp._domainkey.' . $domain->domain, 'IN', 'TXT');

    if (defined($packet) and $packet->header->ancount > 0) {
        my $rr = ($packet->answer)[0];
        if ($rr->type eq 'TXT') {
            $adsp = $rr->txtdata;
        }
    }

    my $smtp = Net::SMTP->new($addr);
    if (defined($smtp)) {
        $starttls = 1 if $smtp->message =~ m|STARTTLS|;
        $banner = $smtp->banner;
    }

    $ms->create(
        {
            starttls  => $starttls,
            adsp      => $adsp,
            ip        => $ip->ip,
            banner    => $banner,
            run_id    => $tr->id,
            domain_id => $domain->id,
            name      => $name,
        }
    );
}

sub collect_geoip_information_for_server {
    my $self = shift;
    my ($tr, $domain) = @_;
    my $ds  = $tr->domainset->domains;
    my $dns = DNSCheck->new->dns;

    # Fetch data from DNSCheck results for DNS servers.
    my $results =
      $tr->search_related('tests', { domain => $domain->domain })
      ->search_related('results', {});

    # Nameservers
    foreach my $t (
        $results->search(
            { message => q[DNS:NAMESERVER_FOUND], arg0 => $domain->domain }
        )->all
      )
    {
        $self->collect_server_information($tr->id, $domain->id, $t->arg3, 'DNS',
            lookup_asn_from_results($t->arg3, $tr, $domain->domain));
    }

    # Mailservers
    print "About to look up MX servers for " . $domain->domain . "\n" if $debug;
    my @mxnames = $dns->find_mx($domain->domain);

    # The standard says to use the domain name if there are no MX records.
    if (@mxnames == 0) {
        @mxnames = ($domain->domain);
    }

    foreach my $name (@mxnames) {
        foreach my $addr ($dns->find_addresses($name, 'IN')) {
            print "Found address $addr\n" if $debug;
            $self->collect_smtp_information($tr, $domain, $addr, $name);
            $self->collect_server_information($tr->id, $domain->id, $addr,
                'SMTP', lookup_asn_from_results($addr, $tr, $domain->domain));
        }
    }

    # Webservers
    foreach my $addr ($dns->find_addresses('www.' . $domain->domain, 'IN')) {
        $self->collect_server_information($tr->id, $domain->id, $addr, 'HTTP',
            lookup_asn_from_results($addr, $tr, $domain->domain));
    }
}

sub collect_server_information {
    my $self = shift;
    my ($trid, $domainid, $ip, $kind, $asn) = @_;
    my $geoip  = Geo::IP->open($self->cget(qw[daemon geoip]));
    my $server = $self->dbx('Server');
    my $ipv6   = 0;

    my $nip = Net::IP->new($ip);
    if (!defined($nip)) {
        croak "Malformed IP adress: $ip";
    } elsif ($nip->version == 6) {
        $ipv6 = 1;
    }

    print "GeoIP lookup for $kind/$trid/$domainid\n" if $debug;
    my $g = $geoip->record_by_addr($ip);
    if ($g) {
        $server->update_or_create(
            {
                domain_id => $domainid,
                run_id    => $trid,
                ip        => $nip->ip,
                ipv6      => $ipv6,
                kind      => $kind,
                country   => $g->country_name,
                code      => $g->country_code,
                city      => $g->city,
                longitude => $g->longitude,
                latitude  => $g->latitude,
                asn       => $asn,
            }
        );
    } else {
        $server->update_or_create(
            {
                domain_id => $domainid,
                run_id    => $trid,
                ip        => $nip->ip,
                ipv6      => $ipv6,
                kind      => $kind,
                asn       => $asn,
            }
        );
    }
}

sub kaminsky_check {
    my $self = shift;
    my $addr = shift;

    # https://www.dns-oarc.net/oarc/services/porttest
    my $res = Net::DNS::Resolver->new(
        nameservers => [$addr],
        recurse     => 1,
    );
    my $p = $res->query('porttest.dns-oarc.net', 'IN', 'TXT', $addr);

    if (defined($p) and $p->header->ancount > 0) {
        my $r = (grep { $_->type eq 'TXT' } $p->answer)[0];
        if ($r) {
            my ($verdict) = $r->txtdata =~ m/ is ([A-Z]+):/;
            return $verdict;
        }
    }

    return "UNKNOWN";
}

1;
__END__

=head1 NAME

Zonestat::Gather - gather statistics

=head1 SYNOPSIS

  use Zonestat;
  
  my $gather = Zonestat->new->gather;

=head1 DESCRIPTION

=head2 Methods

=over 4

=item ->enqueue_domainset($domainset, [$name])

Put all domains in the given domainset object on the gathering queue and
create a new testrun object for it. If a second argument is given, it will be
used as the name of the testrun. If no name is given, a name based on the
current time will be generated.

=item ->get_server_data($trid, $domainname)

Given the ID number of a testrun object and the name of a domain, gather all
data for that domain and store in the database associated with the given
testrun.

=item ->rescan_unknown_servers()

Walk through the list of all Webserver objects with type 'Unknown' and reapply
the list of server type regexps. To be used when the list of regexps has been
extended.

=head1 SEE ALSO

L<Zonestat>.

=head1 AUTHOR

Calle Dybedahl, E<lt>calle@init.seE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Calle Dybedahl

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.9 or,
at your option, any later version of Perl 5 you may have available.


=cut
