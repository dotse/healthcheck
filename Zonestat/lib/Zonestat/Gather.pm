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

our $VERSION = '0.01';
my $debug = 0;
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
);

sub start_dnscheck_entire_zone {
    my $self = shift;

    $self->dbh->do(
q[INSERT INTO queue (domain, priority, source_id, source_data) SELECT domain, 4, ?, ? FROM domains ORDER BY rand()],
        undef, $self->source_id, $self->run_id
    );
}

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

sub get_zone_list {
    my $self = shift;

    map { $_->[0] } @{
        $self->dbh->selectall_arrayref(
            q[SELECT domain FROM domains ORDER BY domain ASC])
      };
}

sub get_http_server_data {
    my $self    = shift;
    my $tr_id   = shift;
    my @domains = @_;
    my $db      = $self->dbx('Domains');
    my %urls    = map { ($_, 'http://www.' . $_) } @domains;

    my $tr = $self->dbx('Testrun')->find($tr_id);

    print "Got " . scalar(@domains) . " domains to check.\n" if $debug;

    while (@domains) {
        my $ua = LWP::Parallel::UserAgent->new(max_size => 1024 * 1024)
          ;    # Don't get more content than one megabyte
        $ua->redirect(0);
        $ua->max_hosts(50);
        $ua->timeout(10);
        $ua->agent('.SE Zonestat');
        print "Created agent.\n" if $debug;
        print "Domains remaining: " . scalar(@domains) . "\n" if $debug;

        foreach my $u (splice(@domains, 0, 25)) {
            $ua->register(HTTP::Request->new(GET => 'http://www.' . $u));
            $ua->register(HTTP::Request->new(GET => 'https://www.' . $u));
            print "Registered $u\n" if $debug;
        }

        print "Waiting..." if $debug;
        my $debug_t = time();
        my $rr      = $ua->wait;
        print time() - $debug_t, " seconds.\n" if $debug;

      DOMAIN:
        foreach my $k (keys %$rr) {
            my $res = $rr->{$k}->response;
            my $url = $res->request->url;
            my $dom;
            my $https;
            my $ip;

            print "Processing result for $url.\n" if $debug;

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
                                content_type =>
                                  scalar($res->header('Content-Type')),
                                content_length =>
                                  scalar($res->header('Content-Length')),
                            }
                        );
                        $obj->update({ ip => $ip }) if defined($ip);
                        next DOMAIN;
                    }
                }
                my $obj = $ddb->add_to_webservers(
                    {
                        type          => 'Unknown',
                        raw_type      => $s,
                        raw_response  => $res,
                        testrun_id    => $tr->id,
                        url           => $url,
                        response_code => $res->code,
                        content_type  => scalar($res->header('Content-Type')),
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

1;
__END__

=head1 NAME

Zonestat::Gather - gather statistics

=head1 SYNOPSIS

  use Zonestat::Gather;

=head1 DESCRIPTION


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
