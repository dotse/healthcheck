# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Zonestat.t'

#########################

use Test::More tests => 8;
BEGIN { use_ok( 'Zonestat::Config' ) }

#########################

my $conf = Zonestat::Config->new('examples/config');
ok( defined( $conf ), 'Object exists.' );
ok( ref( $conf ) eq 'Zonestat::Config', 'Object is of class ' . ref( $conf ) );

ok( $conf->get( qw[couchdb url] ) eq "http://127.0.0.1:5984/", 'Can get a key.' );

$conf->set( 'gurkmos', qw[couchdb url] );
ok( $conf->get( qw[couchdb url] ) eq 'gurkmos', 'Can modify key.' );

$conf = Zonestat::Config->new( dbi => { password => 'foobar' } );
ok( $conf->get( qw[dbi password] ) eq 'foobar', 'Can change defaults.' );

$conf = Zonestat::Config->new( 't/Config' );
ok( $conf->get( 'test' )       eq 'data',     'Can set values from file.' );
ok( $conf->get( qw[dbi user] ) eq 'zonestat', 'Can change defaults from file.' );
