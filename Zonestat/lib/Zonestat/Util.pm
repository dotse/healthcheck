package Zonestat::Util;

use base 'Exporter';

use IPC::Open3;
use Symbol 'gensym';
use IO::File;
use IO::Select;
use POSIX ':signal_h';

our @EXPORT = qw[run_external];

# Runs an external command, with a timeout, and collecting both stdout and stderr from it.
sub run_external {
    my ( $timeout, @args ) = @_;
    my ( $read, $err );
    $err = gensym();
    my %output;
    my $pid     = open3( undef, $read, $err, '-' );
    my $read_no = $read->fileno;
    my $err_no  = $err->fileno;

    if ( $pid ) {    # Parent
        local $SIG{ALRM} = sub { die 'timeout' };
        alarm( $timeout );
        eval {
            my $s = IO::Select->new( $read, $err );
            while ( $s->handles ) {
                foreach my $h ( $s->can_read ) {
                    if ( my $line = $h->getline ) {
                        $output{ $h->fileno } .= $line;
                    }
                    else {
                        $s->remove( $h );
                    }
                }
            }
        };
        if ( $@ and $@ =~ /^timeout/ ) {
            kill 15, $pid;
            return ( undef, '', '' );
        }
        else {
            alarm( 0 );
        }
    }
    else {    # Child
        exec( @args );
    }

    return ( 1, $output{ $read->fileno }, $output{ $err->fileno } );
}

1;