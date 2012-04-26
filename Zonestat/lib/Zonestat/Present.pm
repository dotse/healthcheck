package Zonestat::Present;

use 5.008008;
use strict;
use utf8;
use warnings;

use base 'Zonestat::Common';

use YAML 'LoadFile';
use File::ShareDir 'dist_file';
use Config;
use Storable qw[freeze thaw];

our $VERSION = '0.01';

my $locale = LoadFile dist_file('DNSCheck', 'en.yaml');

sub total_tested_domains {
    my $self = shift;
    my $tr   = shift;

    my $res = $self->dbproxy( 'zonestat' )->test_count( key => 0 + $tr );

    return $res->{rows}[0]{value};
}

sub number_of_domains_with_message {
    my ( $self, $level, @trs ) = @_;
    my %res;

    my $dbp = $self->dbproxy( 'zonestat' );
    foreach my $tr ( @trs ) {
        my $tmp = $dbp->check_withmsg(
            group    => 1,
            startkey => [ $tr, $level, 'A' ],
            endkey   => [ $tr, $level, 'z' ],
        );
        $res{$tr} = { map { $_->{key}[2] => $_->{value} } @{ $tmp->{rows} } };
    }

    return %res;
}

sub number_of_servers_with_software {
    my ( $self, $https, @tr ) = @_;
    my %res;
    my $protocol = $https ? 'https' : 'http';

    my $dbp = $self->dbproxy( 'zonestat' );
    foreach my $tr ( @tr ) {
        my $tmp = $dbp->web_servertype(
            group    => 1,
            startkey => [ 0 + $tr, $protocol, undef ],
            endkey   => [ 0 + $tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
        );
        $res{$tr} = { map { $_->{key}[2] => $_->{value} } @{ $tmp->{rows} } };
    }

    return %res;
}

sub webservers_by_responsecode {
    my ( $self, $https, @tr ) = @_;
    my %res;
    my $protocol = $https ? 'https' : 'http';

    my $dbp = $self->dbproxy( 'zonestat' );
    foreach my $tr ( @tr ) {
        my $tmp = $dbp->web_response(
            group    => 1,
            startkey => [ 0 + $tr, $protocol, undef ],
            endkey   => [ 0 + $tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
        );
        $res{$tr} = { map { $_->{key}[2] => $_->{value} } @{ $tmp->{rows} } };
    }

    return %res;
}

sub webservers_by_contenttype {
    my ( $self, $https, @tr ) = @_;
    my %res;
    my $protocol = $https ? 'https' : 'http';

    my $dbp = $self->dbproxy( 'zonestat' );
    foreach my $tr ( @tr ) {
        my $tmp = $dbp->web_contenttype(
            group    => 1,
            startkey => [ 0 + $tr, $protocol, undef ],
            endkey   => [ 0 + $tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
        );
        $res{$tr} = { map { $_->{key}[2] => $_->{value} } @{ $tmp->{rows} } };
    }

    return %res;
}

sub webservers_by_charset {
    my ( $self, $https, @tr ) = @_;
    my %res;
    my $protocol = $https ? 'https' : 'http';

    my $dbp = $self->dbproxy( 'zonestat' );
    foreach my $tr ( @tr ) {
        my $tmp = $dbp->web_charset(
            group    => 1,
            startkey => [ 0 + $tr, $protocol, undef ],
            endkey   => [ 0 + $tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
        );
        $res{$tr} = { map { $_->{key}[2] => $_->{value} } @{ $tmp->{rows} } };
    }

    return %res;
}

sub unknown_server_strings {
    my $self = shift;

    die "Not ported.";
}

sub all_dnscheck_tests {
    my $self = shift;

    die "Not ported.";
}

sub all_domainsets {
    my $self = shift;

    my $dbp = $self->dbproxy( 'zonestat-dset' );
    return map { $_->{key} } @{ $dbp->util_set( group => 'true' )->{rows} };
}

sub tests_with_max_severity {
    my ( $self, @testruns ) = @_;
    my %res;

    my $dbp = $self->dbproxy( 'zonestat' );
    foreach my $testrun ( @testruns ) {
        my $r = $dbp->check_maxseverity(
            startkey => [ 0 + $testrun->id, 'A' ],
            endkey   => [ 0 + $testrun->id, 'Z' ],
            group    => 'true'
        )->{rows};
        my %tmp = map { $_->{key}[1] => $_->{value} } @$r;
        $res{ $testrun->id } = \%tmp;
    }
    return %res;
}

sub domainset_being_tested {
    my $self = shift;
    my $ds   = shift;

    die "Not ported.";
}

sub top_foo_servers {
    my $self   = shift;
    my $kind   = shift;
    my $tr     = shift;
    my $number = shift || 25;
    my @res;

    my $dbp = $self->dbproxy( 'zonestat' );

    my $tmp = $dbp->stat_toplist(
        startkey    => [ 0 + $tr, $kind ],
        endkey      => [ 0 + $tr, $kind . 'Z' ],
        group_level => 2,
    );

    if ( @{ $tmp->{rows} } == 0 ) {
        return @res;
    }

    my %data = %{ $tmp->{rows}[0]{value} };
    my %host;

    foreach my $key ( keys %data ) {
        my $tmp = $dbp->stat_server( key => $key, limit => 1 );
        $host{$key} = $tmp->{rows}[0]{value};
    }

    @res = sort { $b->[0] <=> $a->[0] }
      map { [ $data{$_}, $_, $host{$_}{latitude}, $host{$_}{longitude}, $host{$_}{country}, $host{$_}{code}, $host{$_}{city}, $host{$_}{asn} ] } keys %data;

    if (@res > $number) {
        splice(@res, $number);
    }

    return @res;
}

## no critic (Subroutines::RequireArgUnpacking)
sub top_dns_servers {
    my $self = shift;
    return $self->top_foo_servers( 'nameserver', @_ );
}

## no critic (Subroutines::RequireArgUnpacking)
sub top_http_servers {
    my $self = shift;
    return $self->top_foo_servers( 'webserver', @_ );
}

## no critic (Subroutines::RequireArgUnpacking)
sub top_smtp_servers {
    my $self = shift;
    return $self->top_foo_servers( 'mailserver', @_ );
}

sub nameservers_per_asn {
    my ( $self, $ipv6, @tr ) = @_;
    my %res;

    my $dbp = $self->dbproxy( 'zonestat' );
    my $ipstr = $ipv6 ? '6' : '4';
    foreach my $t ( @tr ) {
        my $tmp = $dbp->server_ns_per_asn(
            group    => 1,
            startkey => [ $ipstr, $t + 0, 0 ],
            endkey   => [ $ipstr, $t + 1, 0 ],
        );
        $res{$t} = { map { $_->{key}[2] => $_->{value} } @{ $tmp->{rows} } };
    }

    return %res;
}

sub ipv6_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my ( $total, $count );

    my $dbp = $self->dbproxy( 'zonestat' );
    my $tmp = $dbp->server_ipv6_capable( group => 1, key => 0 + $tr )->{rows};

    if ( $tmp ) {
        ( $count, $total ) = @{ $tmp->[0]{value} };
    }

    return ( 100 * ( $count / $total ), $count );    # Percentage, number of v6-domains
}

sub multihome_percentage_for_testrun {
    my ( $self, $tr, $ipv6 ) = @_;
    my $dbp = $self->dbproxy( 'zonestat' );
    my $tmp = $dbp->server_multihomed( group => 1, key => 0 + $tr )->{rows}[0]{value};
    my ( $percentage, $total );

    if ( $tmp ) {
        my ( $v6, $v4 );
        ( $v6, $v4, $total ) = @{$tmp};
        if ( $ipv6 ) {
            $percentage = $v6 / $total;
            return ( 100 * $percentage, $v6 );
        }
        else {
            $percentage = $v4 / $total;
            return ( 100 * $percentage, $v4 );
        }
    }

}

sub dnssec_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my $dbp  = $self->dbproxy( 'zonestat' );
    my $tmp  = $dbp->server_dnssec_capable( group => 1, key => 0 + $tr )->{rows}[0]{value};

    unless ( $tmp ) {
        return ( undef, undef );
    }

    my ( $count, $total ) = @$tmp;

    return ( 100 * ( $count / $total ), $count );
}

sub recursing_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my $dbp  = $self->dbproxy( 'zonestat' );
    my $tmp  = $dbp->server_recursing( group => 1, key => 0 + $tr )->{rows}[0]{value};

    unless ( $tmp ) {
        return ( undef, undef );
    }

    my ( $count, $total ) = @$tmp;

    return ( 100 * ( $count / $total ), $count );
}

sub adsp_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my $dbp  = $self->dbproxy( 'zonestat' );
    my $tmp  = $dbp->server_adsp( group => 1, key => 0 + $tr )->{rows}[0]{value};

    unless ( $tmp ) {
        return ( undef, undef );
    }

    my ( $count, $total ) = @$tmp;

    return ( 100 * ( $count / $total ), $count );
}

sub spf_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my $dbp  = $self->dbproxy( 'zonestat' );
    my $tmp  = $dbp->server_spf( group => 1, key => 0 + $tr )->{rows}[0]{value};

    unless ( $tmp ) {
        return ( undef, undef );
    }

    my ( $count, $total ) = @$tmp;

    return ( 100 * ( $count / $total ), $count );
}

sub starttls_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my $dbp  = $self->dbproxy( 'zonestat' );
    my $tmp  = $dbp->server_starttls( group => 1, key => 0 + $tr )->{rows}[0]{value};

    unless ( $tmp ) {
        return ( undef, undef );
    }

    my ( $count, $total ) = @$tmp;

    return ( 100 * ( $count / $total ), $count );
}

sub nameserver_count {
    my ( $self, $tr, $ipv6 ) = @_;
    my $dbp = $self->dbproxy( 'zonestat-nameserver' );

    my $tmp = $dbp->ns_count(
        group       => 1,
        group_level => 2,
        startkey    => [ "$tr", $ipv6 ? "6" : "4" ],
        endkey      => [ "$tr", $ipv6 ? "7" : "5" ]
    )->{rows}[0]{value};

    return $tmp || 0;
}

sub mailservers_in_sweden {
    my ( $self, $tr, $ipv6 ) = @_;
    my $dbp = $self->dbproxy( 'zonestat' );
    my $tmp = $dbp->server_mx_in_sweden( group => 1, key => 0 + $tr )->{rows}[0]{value};

    unless ( $tmp ) {
        return ( undef, undef );
    }

    my ( $v6count, $v4count, $total ) = @$tmp;

    if ( $total == 0 ) {
        return ( 0, 0 );
    }
    elsif ( $ipv6 ) {
        return ( 100 * ( $v6count / $total ), $v6count );
    }
    else {
        return ( 100 * ( $v4count / $total ), $v4count );
    }
}

sub webserver_count {
    my ( $self, $tr, $https ) = @_;
    my $tmp = $self->dbproxy( 'zonestat' )->server_web( group => 1, key => 0 + $tr )->{rows}[0]{value};

    if ( $https ) {
        return $tmp->{https};
    }
    else {
        return $tmp->{http};
    }
}

sub message_bands {
    my ( $self, @tr ) = @_;
    my %res;

    foreach my $tr ( @tr ) {
        my $r = $self->dbproxy( 'zonestat' )->check_bands(
            group => 'true',
            key   => 0 + $tr,
        )->{rows};
        $res{$tr} = { map { $_->{key} => $_->{value} } @{$r} };
        $res{ $_->{key} } = $_->{value} for @$r;
    }

    return %res;
}

sub lookup_desc {
    my ( $self, $message ) = @_;

    return $locale->{messages}{$message}{descr};
}

sub pageanalyzer_summary {
    my ( $self, @tr ) = @_;
    my %res;

    foreach my $tr ( @tr ) {
        my $res = $self->dbproxy( 'zonestat' )->pageanalyze_summary(
            group => 'true',
            key   => [ 0 + $tr, 'http' ],
        )->{rows};

        $res{$tr} = $res->[0]{value};
    }
    return \%res;
}

sub tests_by_level {
    my ( $self, $level, @trs ) = @_;
    my %res;

    foreach my $tr ( map { 0 + $_ } @trs ) {
        my $r = $self->dbproxy( 'zonestat' )->check_bylevel(
            group    => 1,
            startkey => [ uc( $level ), $tr, '' ],
            endkey   => [ uc( $level ), $tr, 'Z' ],
        )->{rows};
        my @domains = map { $_->{key}[2] } @$r;
        my $view = $self->db( 'zonestat' )->newDesignDoc( '_design/check' );
        $view->retrieve;
        $r = $view->bulkGetView( 'bylevel', [ map { [ $tr, $_ ] } @domains ] );
        $res{$tr} = { map { $_->{key}[1] => $_->{value} } @$r };
    }

    return \%res;
}

1;
__END__

=head1 NAME

Zonestat::Present - present gathered statistics

=head1 SYNOPSIS

  use Zonestat::Present;

=head1 DESCRIPTION

=head2 Methods

=over

=item total_tested_domains($trid)

Takes the ID number of a testrun and returns the total number of domains in it.

=item number_of_domains_with_message($level, @trids)

Takes a level and a list of testruns IDs, and returns a hash where the keys
are the IDs and the values hash references. The hashes referred to have
DNSCheck messages as keys, and the number of domains in that run where the
message in question was emitted as values. The messages counted are those at
the given level. C<$level> must be one of C<CRITICAL>, C<ERROR>, C<WARNING>,
C<NOTICE> and C<INFO>.

=item number_of_servers_with_software($https, @trids)

Takes a flag indicating if results for HTTP (false value) or HTTPS (true
value) should be returned, and a list of testrun IDs. It returns the same kind
of nested hash as described above, except with webserver software names and
counts of them at the inner level.

=item webservers_by_responsecode($https, @trids)

As above, but with protocol response codes instead of webserver software names.

=item webservers_by_contenttype($https, @trids)

As above, but with MIME content types.

=item webservers_by_charset($https, @trids)

As above, but with character encodings.

=item all_domainsets()

Returns a list of the names of all domainsets in the configured CouchDB
instance.

=item tests_with_max_severity(@trs)

Takes a list of L<Zonestat::DB::Testrun> objects, and returns a hash of
hashes. The outer keys are testrun IDs. The keys in the inner hashes are the
severity levels (CRITICAL to DEBUG), and the values the count of domains in
the run for which that severity was the highest one they had.

=item top_foo_servers($type, $trid, [$limit])

Takes two or three arguments: one of the strings C<nameserver>, C<mailserver>
or C<webserver>, the ID of a testrun and optionally a maximum number of items
to return. It returns a list of lists. Each value in the list represents one
server of the asked-for type, and it's sorted in falling order of the number
of times each server was seen during the entire gathering run.

Each value in the list is itself a list. The values in the inner list are, in order:

=over

=item *

Count of occurences.

=item *

IP address.

=item *

Latitude.

=item *

Longitude.

=item *

Country name.

=item *

Country ISO code.

=item *

City, if known.

=item *

A reference to a list of the numbers of all the ASs in which the IP address is
announced.

=back

The C<$limit> argument simply specifies the maximum number of items to return.
If it's not specified, it defaults to 25.

=item top_dns_servers($trid, [$limit])

Calls C<top_foo_servers> with the first argument being 'nameserver'.

=item top_http_servers($trid, [$limit])

Calls C<top_foo_servers> with the first argument being 'webserver'.

=item top_smtp_servers($trid, [$limit])

Calls C<top_foo_servers> with the first argument being 'mailserver'.

=item nameservers_per_asn($v6flag, @trids)

Takes a true/false value to indicate wether to use IPv6 (true) or IPv4
(false), and a list of testrun IDs. Returns a hash of hashes, with the outer
keys being testrun IDs. The inner hashes have AS numbers as keys, and the
number nameservers seen in that AS as values.

=item ipv6_percentage_for_testrun($trid)

Takes a testrun ID, and returns a two-value list. The first value is the
percentage of domains with some kind of IPv6 presence, and the second value
the absolute number of domains with IPv6 presence.

=item multihome_percentage_for_testrun($trid, $v6flag)

Takes a testrun ID and a flag for IPv6/IPv4 (true/false), and returns the
percentage and absolute count of the domains in the testrun that is announced
in more than one AS.

=item dnssec_percentage_for_testrun($trid)

Takes a testrun ID, and returns the percentage and absolute number of domains
in the testrun that is signed with DNSSEC.

=item recursing_percentage_for_testrun($trid)

Takes a testrun ID, and returns the precentage and absolute count of domains
with at least one authoritative nameserver that's open for recursing queries.

=item adsp_percentage_for_testrun($trid)

Takes a testrun ID, and returns the percentage and absolute count of domains
using ADSP.

=item spf_percentage_for_testrun($trid)

Takes a testrun ID, and returns the percentage and absolute count of domains
using SPF.

=item starttls_percentage_for_testrun($trid)

Takes a testrun ID, and returns the percentage and absolute count of domains
with at least one mailserver using STARTTLS.

=item nameserver_count($trid, $v6flag)

Takes a testrun ID and a true/false flag for IPv6/IPv4, and returns the number
of unique nameservers seen in the testrun with the indicated class of address.

=item mailservers_in_sweden($trid, $v6flag)

Takes a testrun ID and a true/false flag for IPv6/IPv4, and returns the
percentage and absolute number of mailservers in the testrun which GeoIP
claims are suituated in Sweden.

=item webserver_count($trid, $httpsflag)

Takes a testrun ID and a true/false flag indicating https/https, and returns
the number of domains in the testrun that replied sensibly to a request with
the given protocol.

=item message_bands(@trids)

Takes a list of testrun IDs. Returns a hash of hashes of hashes. The keys of
the outermost level are the testrun IDs. Below that are three keys, the
strings C<CRITICAL>, C<ERROR> and C<WARNING>. Below each of those are four
keys, the strings C<0>, C<1>, C<2> and C<3+>. The values for each of those
keys are the count of domains in the relevant testrun that has the indicated
number of messages and the given level. So, for example,
C<$result{17}{"ERROR"}{"3+"}> would be the number of domains in testrun 17
that had three or more DNSCheck messages at level ERROR.

=item lookup_desc($dnscheck_message)

Return the English description of a given DNSCheck message.

=item pageanalyzer_summary(@trids)

Returns a reference to a hash of hashes, with the outer level being keyed on
testrun IDs as usual. The inner hashes are statistical summations of the
L<Pageanalyzer> data for the entire testrun. They're fairly large, and we
suggest that you print one out with L<Data::Dumper> or similar to see what's
in there.

=item tests_by_level($level, @trids)

Takes a message level string (C<CRITICAL>, C<ERROR>, C<WARNING>, C<NOTICE>,
C<INFO>) and a list of testrun IDs. Returns reference to a hash of hashes of
hashes. The outermost level is keyed on testrun IDs as usual. The keys on the
next level are the names of all the gathered domains in that testrun with at
least one message at the given level. The value of each domain is a hash with
the five severity levels as keys, and the number of messages at that level for
that domain as values.

This method is quite slow for large testruns and lower severity levels.

=back

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
