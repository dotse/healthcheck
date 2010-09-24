package Zonestat::Collect;

use 5.008008;
use strict;
use warnings;

use base 'Zonestat::Common';

use DNSCheck;
use Time::HiRes qw[time];
use POSIX qw[:signal_h];
use JSON;

use Data::Dumper;

my $debug = 0;

sub for_domain {
    my $self   = shift;
    my $domain = shift;
    my $dc     = DNSCheck->new;
    my %res    = (
        domain => $domain,
        start  => time(),
    );

    $dc->zone->test($domain);
    $res{dc_results} = dnscheck_log_cleanup($dc->logger->export);

    my %hosts = extract_hosts($res{dc_results});
    $hosts{webservers} = get_webservers($domain);
    $res{sslscan_mail} = $self->sslscan_mail($hosts{mailservers});
    $res{sslscan_web}  = $self->sslscan_web($domain);

    $res{pageanalyze} = $self->pageanalyze($domain);
    $res{webinfo}     = $self->webinfo($domain);

    $res{geoip} = $self->geoip(\%hosts);

    print Dumper(\%hosts);
}

sub sslscan_mail {

}

sub sslscan_web {

}

sub pageanalyze {
    my $self = shift;
    my $domain = shift;
    my $padir  = $self->cget(qw[zonestat pageanalyzer]);
    my $python = $self->cget(qw[zonestat python]);
    my %res = ();

    if ($padir and $python and -d $padir and -x $python) {
        foreach my $method (qw[http https]) {
        if(open my $pa, '-|', $python, $padir . '/pageanalyzer.py', '-s', '--nohex', '-t', '300', '-f', 'json', "$method://www.$domain/") {
            $res{$method} = decode_json(join('',<$pa>));
        }
    }
    }
    
    return \%res;
}

sub webinfo {

}

sub geoip {

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
    my $dcref = shift;
    my %res;

    foreach my $r (@$dcref) {
        if ($r->{tag} eq 'DNS:NAMESERVER_FOUND') {
            push @{ $res{nameservers} },
              {
                domain  => $r->{args}[0],
                name    => $r->{args}[2],
                address => $r->{args}[3]
              };
        } elsif ($r->{tag} eq 'DNS:FIND_MX_RESULT') {
            foreach my $s (split(/,/, $r->{args}[1])) {
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

    my $dns = DNSCheck->new->dns;
    my $r = $dns->query_resolver("www.$domain", 'A', 'IN');
    if (defined($r) and $r->header->ancount > 0) {
        foreach my $rr ($r->answer) {
            push @res, { name => $rr->name, address => $rr->address };
        }
    }

    return \@res;
}

1;
