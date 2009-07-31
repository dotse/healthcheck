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

our $VERSION = '0.01';
my $debug = 0;
STDOUT->autoflush(1) if $debug;

our %server_regexps = (
    qr|^Apache/?(\S+)?|                => 'Apache',
    qr|^Microsoft-IIS/(\S+)|           => 'Microsoft IIS',
    qr|^nginx/?(\S+)?|                 => 'nginx',
    qr|^Lotus-Domino|                  => 'Lotus Domino',
    qr|^GFE/(\S+)|                     => 'Google Web Server',
    qr|^lighttpd/?(\S+)|               => 'lighttpd',
    qr|^WebServerX|                    => 'WebServerX',
    qr|^Zope/\(Zope ([-a-zA-Z0-9.]+)|  => 'Zope',
    qr|^Resin/?(\S+)?|                 => 'Resin',
    qr|^Roxen.{0,2}Challenger/?(\S+)?| => 'Roxen',
    qr|^ODERLAND|                      => 'Oderland',
    qr|WebSTAR/?(\S+)|                 => 'WebSTAR',
    qr|^IBM_HTTP_Server|               => 'IBM HTTP Server (WebSphere)',
    qr|^Zeus/?(\S+)|                   => 'Zeus',
    qr|^Oversee Webserver v(\S+)|      => 'Oversee',
    qr|^Sun Java System Application Server (\S+)| =>
      'Sun Java System Application Server (GlassFish)',
    qr|^AkamaiGHost|       => 'Akamai',
    qr|^Stronghold/?(\S+)| => 'RedHat Stronghold',
);

sub start_dnscheck_entire_zone {
    my $self = shift;

    $self->dbh->do(
q[INSERT INTO queue (domain, priority, source_id, source_data) SELECT domain, 4, ?, ? FROM domains ORDER BY rand()],
        undef, $self->source_id, $self->run_id
    );
}

sub enqueue_domains {
    my $self = shift;

    my $q = $self->dbx('Queue');
    foreach my $dom (@_) {
        if (ref($dom) eq 'Zonestat::DBI::Result::Domains') {
            $q->create(
                {
                    domain      => $dom->domain,
                    source_id   => $self->source_id,
                    source_data => $self->run_id,
                    priority    => 4
                }
            );
        } else {
            $q->create(
                {
                    domain      => $dom,
                    source_id   => $self->source_id,
                    source_data => $self->run_id,
                    priority    => 4
                }
            );
        }
    }
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
    my @domains = @_;
    my $db      = $self->dbx('Domains');
    my %urls    = map { ($_, 'http://www.' . $_) } @domains;

    print "Got " . scalar(@domains) . " domains to check.\n" if $debug;

    while (@domains) {
        my $ua = LWP::Parallel::UserAgent->new;
        $ua->redirect(0);
        $ua->max_hosts(50);
        $ua->timeout(10);
        $ua->agent('.SE Zonestat');
        print "Created agent.\n" if $debug;
        print "Domains remaining: " . scalar(@domains) . "\n" if $debug;

        foreach my $u (splice(@domains, 0, 25)) {
            $ua->register(HTTP::Request->new(HEAD => 'http://www.' . $u));
            $ua->register(HTTP::Request->new(HEAD => 'https://www.' . $u));
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
                        $ddb->add_to_webservers(
                            {
                                type    => $server_regexps{$r},
                                version => $1,
                                raw     => $s,
                                https   => $https,
                                issuer  => $issuer,
                            }
                        );
                        next DOMAIN;
                    }
                }
                $ddb->add_to_webservers(
                    {
                        type => 'Unknown',
                        raw  => $s
                    }
                );
            }
        }
    }
}

sub rescan_unknown_servers {
    my $self = shift;
    my $db = $self->dbx('Webserver')->search({ type => 'Unknown' });

  DOMAIN:
    while (my $row = $db->next) {
        my $str = $row->raw;
        foreach my $r (keys %server_regexps) {
            if ($str =~ $r) {
                print "Updating to "
                  . $server_regexps{$r} . ": "
                  . $row->raw . "\n"
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
