package Zonestat::Collect::Whatweb;

our $debug = $Zonestat::Collect::debug;
our $dc    = $Zonestat::Collect::dc;
our $dns   = $Zonestat::Collect::dns;
our $asn   = $Zonestat::Collect::asn;

sub collect {
    my ($self, $domain, $parent) = @_;
    
    return ('whatweb', whatweb($parent, $domain));
}

sub whatweb {
    my $self   = shift;
    my $domain = shift;
    my $ww     = $self->cget( qw[zonestat whatweb] );
    my %res    = ();
    my $url    = "http://www.$domain";

    return unless -x $ww;

    my ( $success, $stdout, $stderr ) = Zonestat::Collect::run_external( 120, $ww, '--log-json=/dev/stdout', '--quiet', $url );
    if ( $success and $stdout ) {
        my $tmp = join( ', ', split( /\n/, $stdout ) );
        my $data;
        try {
            $data = decode_json( "[$tmp]" );    # WhatWeb does not always produce valid JSON...
        };
        return $data;
    }
    else {
        return;
    }
}

1;