package Zonestat::Present;

use 5.008008;
use strict;
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

### FIXME: Special table for DNSSEC problems.

sub number_of_domains_with_message {
    my $self  = shift;
    my $level = shift;
    my @trs   = @_;
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
    my $self = shift;
    my ( $https, @tr ) = @_;
    my %res;
    my $protocol = $https ? 'https' : 'http';

    my $dbp = $self->dbproxy( 'zonestat' );
    foreach my $tr ( @tr ) {
        my $tmp = $dbp->web_servertype(
            group    => 1,
            startkey => [ $tr, $protocol, undef ],
            endkey   => [ $tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
        );
        $res{$tr} = { map { $_->{key}[2] => $_->{value} } @{ $tmp->{rows} } };
    }

    return %res;
}

sub webservers_by_responsecode {
    my $self = shift;
    my ( $https, @tr ) = @_;
    my %res;
    my $protocol = $https ? 'https' : 'http';

    my $dbp = $self->dbproxy( 'zonestat' );
    foreach my $tr ( @tr ) {
        my $tmp = $dbp->web_response(
            group    => 1,
            startkey => [ $tr, $protocol, undef ],
            endkey   => [ $tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
        );
        $res{$tr} = { map { $_->{key}[2] => $_->{value} } @{ $tmp->{rows} } };
    }

    return %res;
}

sub webservers_by_contenttype {
    my $self = shift;
    my ( $https, @tr ) = @_;
    my %res;
    my $protocol = $https ? 'https' : 'http';

    my $dbp = $self->dbproxy( 'zonestat' );
    foreach my $tr ( @tr ) {
        my $tmp = $dbp->web_contenttype(
            group    => 1,
            startkey => [ $tr, $protocol, undef ],
            endkey   => [ $tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
        );
        $res{$tr} = { map { $_->{key}[2] => $_->{value} } @{ $tmp->{rows} } };
    }

    return %res;
}

sub webservers_by_charset {
    my $self = shift;
    my ( $https, @tr ) = @_;
    my %res;
    my $protocol = $https ? 'https' : 'http';

    my $dbp = $self->dbproxy( 'zonestat' );
    foreach my $tr ( @tr ) {
        my $tmp = $dbp->web_charset(
            group    => 1,
            startkey => [ $tr, $protocol, undef ],
            endkey   => [ $tr, $protocol, 'zzzzzzzzzzzzzzzzzzzz' ],
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
    my $self    = shift;
    my $testrun = shift;

    my $dbp = $self->dbproxy( 'zonestat' );
    my $res = $dbp->check_maxseverity(
        startkey => [ '' . $testrun, 'A' ],
        endkey   => [ '' . $testrun, 'Z' ],
        group    => 'true'
    )->{rows};

    return map { $_->{key}[1] => $_->{value} } @$res;
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

sub top_dns_servers {
    my $self = shift;
    return $self->top_foo_servers( 'nameserver', @_ );
}

sub top_http_servers {
    my $self = shift;
    return $self->top_foo_servers( 'webserver', @_ );
}

sub top_smtp_servers {
    my $self = shift;
    return $self->top_foo_servers( 'mailserver', @_ );
}

sub nameservers_per_asn {
    my $self = shift;
    my @tr   = @_;
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

    return ( ( $count / $total ), $total );    # Percentage, number of v6-domains
}

sub multihome_percentage_for_testrun {
    my $self = shift;
    my ( $tr, $ipv6 ) = @_;
    my $dbp = $self->dbproxy( 'zonestat' );
    my $tmp = $dbp->server_multihomed( group => 1, key => 0 + $tr )->{rows}[0]{value};
    my ( $percentage, $total );

    if ( $tmp ) {
        my ( $v6, $v4 );
        ( $v6, $v4, $total ) = @{$tmp};
        if ( $ipv6 ) {
            $percentage = $v6 / $total;
        }
        else {
            $percentage = $v4 / $total;
        }
    }

    return ( 100 * $percentage, $total );
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

    return ( 100 * ( $count / $total ), $total );
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

    return ( 100 * ( $count / $total ), $total );
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

    return ( 100 * ( $count / $total ), $total );
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

    return ( 100 * ( $count / $total ), $total );
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

    return ( 100 * ( $count / $total ), $total );
}

sub nameserver_count {
    my $self = shift;
    my ( $tr, $ipv6 ) = @_;
    my $dbp = $self->dbproxy( 'zonestat' );
    my $tmp = $dbp->server_ns_count(
        group    => 1,
        startkey => [ 0 + $tr, $ipv6 ? "6" : "4" ],
        endkey   => [ 0 + $tr, $ipv6 ? "7" : "5" ]
    )->{rows};

    warn "Warning: This method is horribly inefficient, and should not be used";
    unless ( $tmp ) {
        return ( undef, undef );
    }

    return scalar @$tmp;
}

sub mailservers_in_sweden {
    my $self = shift;
    my ( $tr, $ipv6 ) = @_;
    my $dbp = $self->dbproxy( 'zonestat' );
    my $tmp = $dbp->server_mx_in_sweden( group => 1, key => 0 + $tr )->{rows}[0]{value};

    unless ( $tmp ) {
        return ( undef, undef );
    }

    my ( $v6count, $v4count, $total ) = @$tmp;

    if ( $ipv6 ) {
        return (100*($v6count/$total), $v6count);
    }
    else {
        return (100*($v4count/$total), $v4count);
    }
}

sub message_bands {
    my $self = shift;
    my @tr   = @_;
    my %res;

    foreach my $tr ( @tr ) {
        my $res = $self->dbproxy( 'zonestat' )->check_bands(
            group => 'true',
            key   => "$tr",
        )->{rows};
        $res{$tr} = { map { $_->{key} => $_->{value} } @{$res} };
    }

    return %res;
}

sub lookup_desc {
    my $self = shift;
    my ( $message ) = @_;

    return $locale->{messages}{$message}{descr};
}

sub pageanalyzer_summary {
    my $self = shift;
    my @tr   = @_;
    my %res;

    foreach my $tr ( @tr ) {
        my $res = $self->dbproxy( 'zonestat' )->pageanalyze_summary(
            group    => 'true',
            startkey => [ '' . $tr, 'A' ],
            endkey   => [ '' . $tr, 'z' ]
        )->{rows};

        $res{$tr} = { map { $_->{key}[1] => $_->{value} } @{$res} };
    }
    return %res;
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
