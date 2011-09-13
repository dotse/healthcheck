package Zonestat::Present;

use 5.008008;
use strict;
use utf8;
use warnings;

use base 'Zonestat::Common';

use YAML 'LoadFile';
use Config;
use Storable qw[freeze thaw];

our $VERSION = '0.01';

my $locale = LoadFile $Config{siteprefix} . '/share/dnscheck/locale/en.yaml';

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
            startkey => [ 0+$tr, $protocol, undef ],
            endkey   => [ 0+$tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
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
            startkey => [ 0+$tr, $protocol, undef ],
            endkey   => [ 0+$tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
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
            startkey => [ 0+$tr, $protocol, undef ],
            endkey   => [ 0+$tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
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
            startkey => [ 0+$tr, $protocol, undef ],
            endkey   => [ 0+$tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
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
    my $kind   = lc( shift );
    my $tr     = shift;
    my $number = shift || 25;
    my @res;

    my $dbp     = $self->dbproxy( 'zonestat' );
    my $endkind = $kind;
    $endkind++;
    my $tmp = $dbp->server_data(
        group_level => 9,
        startkey    => [ 0 + $tr, $kind ],
        endkey      => [ 0 + $tr, $endkind ],
    );

    foreach my $e ( @{ $tmp->{rows} } ) {
        push @res, [ $e->{value}, @{ $e->{key} }[ 2 .. 8 ] ];
    }

    return ( ( sort { $b->[0] <=> $a->[0] } @res )[ 0 .. $number - 1 ] );
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
    my ( $self, @tr ) = @_;
    my %res;

    my $dbp = $self->dbproxy( 'zonestat' );
    foreach my $t ( @tr ) {
        my $tmp = $dbp->server_ns_per_asn(
            group    => 1,
            startkey => [ $t + 0 ],
            endkey   => [ $t + 1 ],
        );
        $res{$t} = { map { $_->{key}[1] => $_->{value} } @{ $tmp->{rows} } };
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

    if ( $ipv6 ) {
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
            group    => 'true',
            key => [ 0 + $tr, 'http' ],
        )->{rows};

        $res{$tr} = $res->[0]{value};
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
