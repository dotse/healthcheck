package MockResolver;

use JSON::XS;
use Net::DNS;
use Net::IP;
use File::Slurp;
use Carp;

# This is where we store the mockup data.
our $data;

# Should we be talkative?
our $verbose = 0;
our $mult = undef;

# Called at use() time.
sub import {
    my ($class, $test, $flags) = @_;
    load($test) if $test;
    
    $mult = 1 if $flags->{multiple};
}

# Load mockup data.
sub load {
    my ($test) = @_;

    my $json = read_file("t/$test.json");
    if ($json) {
        $data = decode_json($json);
    } else {
        croak "Failed to load mockup data for test $test\n";
    }
}

# Build and return a fake packet.
sub mockup {
    my ($name, $type, $class, $server) = @_;
    my $d;
    
    if (!$data->{$name}{$type}{$class}) {
        return;
    }
    
    if ($mult) {
        if (!$server) {
            # No server given, pick one
            my @tmp = keys %{$data->{$name}{$type}{$class}};
            $server = $tmp[0];
        }
        
        $d = $data->{$name}{$type}{$class}{$server};
    } else {
        $d = $data->{$name}{$type}{$class};
    }
    
    if (!$d) {
        return;
    }
    
    my $p = Net::DNS::Packet->new($name, $type, $class);
    
    foreach my $section (qw[answer additional authority]) {
        if ($d->{$section}) {
            foreach my $str (@{$d->{$section}}) {
                my $rr = Net::DNS::RR->new($str);
                $p->unique_push($section, $rr);
            }
        }
    }
    my $nh = $p->header;

    my $oh = $d->{header};
    if ($oh) {
        $nh->rcode($oh->{rcode});
        $nh->opcode($oh->{opcode});
        $nh->qr($oh->{qr});
        $nh->aa($oh->{aa});
        $nh->tc($oh->{tc});
        $nh->rd($oh->{rd});
        $nh->cd($oh->{cd});
        $nh->ra($oh->{ra});
        $nh->ad($oh->{ad});
    } else {
        $nh->rcode('NOERROR');
    }
    
    if ($server) {
        $p->answerfrom($server);
    } else {
        $p->answerfrom('127.0.0.1');
    }

    return $p;
}

1;

package Net::DNS::Resolver;

# And now let's fake up the DNS resolver.

use strict;
use warnings;
use 5.8.9;

# Tell Perl Net::DNS::Resolver is already loaded, so it doesn't pull in the real one later.
$INC{'Net/DNS/Resolver.pm'} = 'mocked';

# Clean out any remains, if it already was loaded.
BEGIN {
    foreach my $name (keys %{$::{'Net::'}{'DNS::'}{'Resolver::'}}) {
        if ($name =~ /::$/) {
            delete $::{'Net::'}{'DNS::'}{'Resolver::'}{$name}
        }
    }
}

our @ISA = ();

our $AUTOLOAD;

sub new {
    return bless {};
}

sub send {
    my ($self, $name, $type, $class) = @_;
    if ($type eq 'IN' or $type eq 'CH') {
        ($class, $type) = ($type, $class);
    }
    $name =~ s/\.$//;
    print STDERR "send: $name $type $class\n" if $verbose;
    
    my $p = MockResolver::mockup($name, $type, $class, $self->{ns});
    print STDERR "No data.\n" if ($verbose and not $p);
    return $p;
}

sub nameservers {
    my ($self, @servers) = @_;
    
    if(@servers > 0) {
        my $raw = $servers[0];
        if($raw) {
            $self->{ns} = Net::IP->new($servers[0])->ip;
        }
    }
    
    return $self->{ns};
}

sub axfr_start {
    return 1; # Pretend it's OK
}

sub axfr_next {
    return; # Pretend we're done
}

sub errorstring { # Do this properly at some point.
    return 'unknown error or no error';
}

# Just stub out a bunch of methods for now.
sub persistent_tcp {}
sub cdflag {}
sub recurse {}
sub udp_timeout {}
sub tcp_timeout {}
sub retry {}
sub retrans {}
sub force_v4 {}
sub usevc {}
sub defnames {}
sub udppacketsize {}
sub debug {}
sub init {}
sub read_config_file {}
sub read_env {}
sub dnssec {}
sub print {}
sub yxdomain {}
sub confess {}
sub bgread {}
sub carp {}
sub bgisready {}
sub searchlist {}
sub query {}
sub import {}
sub string {}
sub mx {}
sub defaults {}
sub nameserver {}
sub croak {}
sub nxdomain {}
sub search {}
sub axfr {}
sub yxrrset {}
sub bgsend {}
sub nxrrset {}
sub tsig {}

## Perl-internal stuff
sub DESTROY {
    # Det är vi, sågspånen
}

sub AUTOLOAD {
    print STDERR "needs to be mocked: $AUTOLOAD\n";
}

###
### For now, we simply block SMTP tests by having them all fail.
###

package Net::SMTP;
use Carp;
$INC{'Net/SMTP.pm'} = 'mocked';
our @INC = ();

our $VERSION = 4711;

sub new {
    my $class = shift;
    my %arg = @_;

    return bless {host => $arg{Host}};
}

sub message {
    my $self = shift;
    
    my $msg = shift @{$data->{'_smtp'}{$self->{host}}};
    
    if (defined($msg)) {
        push @{$data->{'_smtp'}{$self->{host}}}, $msg;
        return $msg;
    }
    else {
        croak 'SMTP::message ==> ' . $self->{host};
    }
}

sub banner {
    goto &message;
}

sub status {goto &message;}

sub mail {;}

sub recipient {;}

sub reset {;}

sub quit {;}

1;