#!/opt/local/bin/perl

=pod

Takes one or more domain names as command line arguments, and adds them to the
gathering queue with randomized priorities.

=cut

use warnings;
use strict;

use Zonestat;

STDOUT->autoflush( 1 );

my $zs = Zonestat->new;

$zs->gather->put_in_queue( map { { domain => $_, priority => 1 + int( rand( 10 ) ) } } @ARGV );
