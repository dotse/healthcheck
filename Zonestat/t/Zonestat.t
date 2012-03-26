# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Zonestat.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

#########################

my $zs = Zonestat->new;
ok( defined( $zs ), 'Object can be created.' );
ok( $zs->cget( qw[couchdb url] ) eq "http://127.0.0.1:5984/", 'Default config data is there.' );
$zs = Zonestat->new( test => 'data' );
ok( $zs->cget( 'test' ) eq 'data', 'Can set defaults.' );

done_testing;