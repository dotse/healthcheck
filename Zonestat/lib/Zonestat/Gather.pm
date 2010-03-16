package Zonestat::Gather;

use 5.008008;
use strict;
use warnings;

use DNSCheck;

use base 'Zonestat::Common';

use LWP::Simple;
use LWP::UserAgent;
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

sub from_plugins {
    my $self = shift;
    my ($trid, $domainname) = @_;

    my $testrun = $self->dbx('Testrun')->find($trid);
    my $domain =
      $self->dbx('Domains')->search({ domain => $domainname })->first;

    foreach my $plugin ($self->parent->plugins) {
        $plugin->gather($domain, $testrun);
    }
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

sub check_robots_txt {
    my ($url) = @_;

    return !!get($url . 'robots.txt');
}

# We need to implement a timeout. Specific trigger for this was www.seb.se,
# which would accept a TCP connection but never respond to SSL negotiation.
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

sub pageanalyze {
    my ($self, $ws) = @_;
    my $padir  = $self->cget(qw[zonestat pageanalyzer]);
    my $python = $self->cget(qw[zonestat python]);
    my @report4;
    my @report5;

    if (chdir($padir)) {
        if (open my $pa,
            '-|', $python, '-Wi::DeprecationWarning', 'pageanalyzer.py',
            $ws->url)
        {
            while (my $line = <$pa>) {
                chomp($line);
                my @fields = split /;/, $line;
                if (!$fields[1]) {
                    next;
                } elsif ($fields[1] eq 'REPORT5') {
                    @report5 = @fields;
                } elsif ($fields[1] eq 'REPORT4') {
                    push @report4, [@fields];
                } else {

                    # Not interested in this
                }
            }
            my $obj = $ws->create_related(
                'pageanalysis',
                {
                    load_time             => $report5[2],
                    requests              => $report5[3],
                    rx_bytes              => $report5[4],
                    compressed_resources  => $report5[5],
                    average_compression   => $report5[6],
                    effective_compression => $report5[7],
                    external_resources    => $report5[8],
                    error                 => $report5[9]
                }
            );
            foreach my $r (@report4) {
                $obj->create_related(
                    'result_rows',
                    {
                        url                  => pack('H*', $r->[2]),
                        ip                   => $r->[3],
                        resource_type        => $r->[4],
                        found_in             => pack('H*', $r->[5]),
                        depth                => $r->[6],
                        start_order          => $r->[7],
                        offset_time          => $r->[8],
                        time_in_queue        => $r->[9],
                        dns_lookup_time      => $r->[10],
                        connect_time         => $r->[11],
                        redirect_time        => $r->[12],
                        first_byte           => $r->[13],
                        download_time        => $r->[14],
                        load_time            => $r->[15],
                        status_code          => $r->[16],
                        compressed           => $r->[17],
                        compression_ratio    => $r->[18],
                        compressed_file_size => $r->[19],
                        file_size            => $r->[20],
                        request_headers      => pack('H*', $r->[21]),
                        response_headers     => pack('H*', $r->[22]),
                        error                => $r->[23]
                    }
                );
            }
        } else {
            warn "Failed to run pageanalyser: $!\n";
        }
    }
}

sub get_http_server_data {
    my $self     = shift;
    my $tr_id    = shift;
    my ($domain) = @_;
    my $db       = $self->dbx('Domains');
    my $tr       = $self->dbx('Testrun')->find($tr_id);

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

        if ($https and !defined($ssl)) {

            # We have an HTTPS URL, but can't establish an SSL connection. Skip.
            next DOMAIN;
        }

        $res    = $ua->get($u);
        $robots = check_robots_txt($u);

        my $rcount = scalar($res->redirects);
        my $rurls = join ' ', map { $_->base } $res->redirects;
        $rurls .= ' ' . $res->base;

        # Don't try to deal with anything but HTTP.
        next DOMAIN unless $res->base->scheme eq 'http';

        my ($tld) = $res->base->host =~ m|\.([-_0-9a-z]+)(:\d+)?$|i;

        my $ddb = $db->search({ domain => $domain })->first;
        unless (defined($ddb)) {
            carp "Failed to find domain: $domain";
            return;
        }

        if ($res->header('Client-Peer')) {
            $ip = ((split(/:/, $res->header('Client-Peer')))[0]);
        }

        my $issuer;

        if (my $s = $res->header('Server')) {
            if ($https and $ssl) {
                $issuer = $ssl->peer_certificate('issuer');
            }

            foreach my $r (keys %server_regexps) {
                if ($s =~ $r) {
                    my ($type, $encoding) =
                      content_type_from_header($res->header('Content-Type'));
                    my $obj = $ddb->add_to_webservers(
                        {
                            type          => $server_regexps{$r},
                            version       => $1,
                            raw_type      => $s,
                            https         => $https,
                            issuer        => $issuer,
                            raw_response  => $res,
                            testrun_id    => $tr->id,
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
                        }
                    );
                    $obj->update({ ip => $ip }) if defined($ip);
                    $self->pageanalyze($obj);
                    next DOMAIN;
                }
            }
            my ($type, $encoding) =
              content_type_from_header($res->header('Content-Type'));
            my $obj = $ddb->add_to_webservers(
                {
                    type           => 'Unknown',
                    raw_type       => $s,
                    raw_response   => $res,
                    testrun_id     => $tr->id,
                    url            => $u,
                    response_code  => $res->code,
                    content_type   => $type,
                    charset        => $encoding,
                    content_length => scalar($res->header('Content-Length')),
                    redirect_count => $rcount,
                    redirect_urls  => $rurls,
                    ending_tld     => $tld,
                    robots_txt     => $robots,
                }
            );
            $obj->update({ ip => $ip }) if defined($ip);
            $self->pageanalyze($obj);
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
    my $spf_spf;
    my $spf_txt;
    my $starttls = 0;
    my $banner;

    my $ip = Net::IP->new($addr);
    croak "Malformed IP address: $addr" unless defined($ip);

    my $dns = DNSCheck->new->dns;

    # DKIM/ADSP
    my $packet =
      $dns->query_resolver('_adsp._domainkey.' . $domain->domain, 'IN', 'TXT');

    if (defined($packet) and $packet->header->ancount > 0) {
        my $rr = ($packet->answer)[0];
        if ($rr->type eq 'TXT') {
            $adsp = $rr->txtdata;
        }
    }

    # SPF, "real" kind
    $packet = $dns->query_resolver($domain->domain, 'IN', 'SPF');
    if (defined($packet) and $packet->header->ancount > 0) {
        my $rr = (grep { $_->type eq 'SPF' } $packet->answer)[0];
        if ($rr) {
            $spf_spf = $rr->txtdata;
        }
    }

    # SPF, transitionary kind
    $packet = $dns->query_resolver($domain->domain, 'IN', 'TXT');
    if (defined($packet) and $packet->header->ancount > 0) {
        my $rr = (grep { $_->type eq 'TXT' } $packet->answer)[0];
        if ($rr and $rr->txtdata =~ /^v=spf/) {
            $spf_txt = $rr->txtdata;
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
            spf_spf   => $spf_spf,
            spf_txt   => $spf_txt,
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
            $verdict ||= 'UNKNOWN';
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
