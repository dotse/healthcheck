package Zonestat::Collect::Sslscan;

use strict;
use warnings;

use Zonestat::Util;
use Try::Tiny;
use XML::Simple;
use Carp;

our $debug = $Zonestat::Collect::debug;

sub collect {
    my ($self, $domain, $parent) = @_;
    
    return ('sslscan_web', sslscan_web($parent, $domain));
}

sub sslscan_web {
    my $self   = shift;
    my $domain = shift;
    my $scan   = $self->cget( qw[zonestat sslscan] );
    my %res    = ();
    my $name   = "www.$domain";

    return \%res unless ($scan and -x $scan);

    my $cmd = "$scan --xml=stdout --quiet --no-failed";
    $res{name} = $name;
    my ( $success, $stdout, $stderr ) = run_external( 600, $cmd . ' ' . $name );
    try {
        $res{data} = XMLin( $stdout );
    };
    if ( $stderr and $debug ) {    # sslscan prints lots of garbage on STDERR.
        print STDERR "[$$] $cmd: $stderr\n";
    }

    $res{evaluation} = sslscan_evaluate( $res{data} );
    $res{known_ca}   = https_known_ca($self, $domain );

    return \%res;
}

## no critic (TestingAndDebugging::ProhibitNoWarnings)
sub sslscan_evaluate {
    no warnings 'uninitialized';
    my $data = shift;
    $data = $data->{ssltest};
    my %result;

    # Check renegotiation status.
    if ( $data->{renegotiation}{secure} and $data->{renegotiation}{supported} ) {
        $result{renegotiation} = 'secure';
    }
    elsif ( $data->{renegotiation}{supported} ) {
        $result{renegotiation} = 'insecure';
    }
    else {
        $result{renegotiation} = 'none';
    }

    my @default = ();
    if ( defined( $data->{defaultcipher} )
        and ref( $data->{defaultcipher} ) eq 'ARRAY' )
    {
        @default = @{ $data->{defaultcipher} };
    }
    elsif ( defined( $data->{defaultcipher} )
        and ref( $data->{defaultcipher} ) eq 'HASH' )
    {
        @default = ( $data->{defaultcipher} );
    }

    # Check support for HTTPS
    $result{https_support} = ( @default > 0 );

    # Check support for SSL versions
    $result{sslv2} = !!( grep { $_->{sslversion} eq 'SSLv2' } @default );
    $result{sslv3} = !!( grep { $_->{sslversion} eq 'SSLv3' } @default );
    $result{tlsv1} = !!( grep { $_->{sslversion} eq 'TLSv1' } @default );

    # We're going to traverse this list a few times.
    my @cipher;
    if ( defined( $data->{cipher} ) and ref( $data->{cipher} ) eq 'ARRAY' ) {
        @cipher = @{ $data->{cipher} };
    }
    elsif ( defined( $data->{cipher} ) and ref( $data->{cipher} ) eq 'HASH' ) {
        @cipher = ( $data->{cipher} );
    }
    @cipher = grep { $_->{status} eq 'accepted' } @cipher;

    # Is authentication without key permitted?
    $result{no_key_auth} = !!( grep { $_->{au} eq 'None' } @cipher );

    $result{no_encryption}     = !!( grep { $_->{bits} == 0 } @cipher );
    $result{weak_encryption}   = !!( grep { $_->{bits} < 128 } @cipher );
    $result{medium_encryption} = !!( grep { $_->{bits} >= 128 and $_->{bits} < 256 } @cipher );
    $result{strong_encryption} = !!( grep { $_->{bits} >= 256 } @cipher );

    # This relies on the special EV OID _not_ getting translated to a name.
    $result{ev_cert} = !!( index( $data->{certificate}{subject}, '1.3.6.1.4.1.311.60.2.1.3' ) >= 0 );

    return \%result;
}

sub https_known_ca {
    my $self   = shift;
    my $server = shift;

    my $openssl  = $self->cget( qw[zonestat openssl] );
    my $certfile = $self->cget( qw[zonestat cacertfile] );

    unless ( $openssl and $certfile ) {
        return;
    }

    unless ( -x $openssl and -r $certfile ) {
        confess "$openssl not executable or $certfile not readable";
    }

    my $raw = qx[$openssl s_client -CAfile $certfile -connect www.$server:443 < /dev/null 2>/dev/null];

    if ( $raw =~ m|Verify return code: \d+ \(([^)]+)\)| ) {
        my $verdict = $1;
        if ( $verdict eq 'ok' ) {
            return { ok => 1, verdict => $verdict };
        }
        else {
            return { ok => 0, verdict => $verdict };
        }
    }
    else {
        return { ok => undef, verdict => undef };
    }
}

1;