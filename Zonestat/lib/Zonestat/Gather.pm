package Zonestat::Gather;

use 5.008008;
use strict;
use warnings;

use DNSCheck;

use base 'Zonestat::Common';

use LWP::UserAgent;

our $VERSION = '0.01';

our %server_regexps = (
    qr|^Apache/?(\S+)?|      => 'Apache',
    qr|^Microsoft-IIS/(\S+)| => 'Microsoft IIS',
    qr|^nginx/(\S+)|         => 'nginx',
    qr|^Lotus-Domino|        => 'Lotus Domino',
    qr|^GFE/(\S+)|           => 'Google Web Server',
    qr|lighttpd/(\S+)|       => 'lighttpd',
);

our $ua = LWP::UserAgent->new;
$ua->agent('.SE Zonestat');

sub start_dnscheck_zone {
    my $self = shift;

    $self->dbh->do(
q[INSERT INTO queue (domain, priority, source_id, source_data) SELECT domain, 4, ?, ? FROM domains ORDER BY rand()],
        undef, $self->source_id, $self->run_id
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
    my @domains = @_;
    my $db      = $self->dbx('Domains');
    my %data;

  DOMAIN:
    foreach my $dom (@domains) {
        my $ddb = $db->search({ domain => $dom })->first;
        my $res =
          $ua->request(HTTP::Request->new(HEAD => 'http://www.' . $dom));
        if ($res->is_success) {
            my $s = $res->header('Server') || '';
            foreach my $r (keys %server_regexps) {
                if ($s =~ $r) {
                    $ddb->add_to_webservers(
                        {
                            type    => $server_regexps{$r},
                            version => $1,
                            raw     => $s
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
