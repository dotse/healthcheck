package Zonestat::Collect::Pageanalyze;

use strict;
use warnings;

use Zonestat::Util;
use JSON::XS;

our $debug = $Zonestat::Collect::debug;

sub collect {
    my ($self, $domain, $parent) = @_;
    
    return ('pageanalyze', pageanalyze($parent, $domain));
}

sub pageanalyze {
    my $self   = shift;
    my $domain = shift;
    my $padir  = $self->cget( qw[zonestat pageanalyzer] );
    my $python = $self->cget( qw[zonestat python] );
    my %res    = ();

    if ( $padir and $python and -d $padir and -x $python ) {
        foreach my $method ( qw[http https] ) {
            my ( $success, $stdout, $stderr ) = run_external( 600, $python, $padir . '/pageanalyzer.py', '-s', '--nohex', '-t', '300', '-f', 'json', "$method://www.$domain/" );
            if ( $success and $stdout ) {
                $res{$method} = decode_json( $stdout );
                delete $res{$method}{resources};
            }
            if ( $debug and $stderr ) {
                print STDERR $stderr;
            }
        }
    }

    return \%res;
}

1;