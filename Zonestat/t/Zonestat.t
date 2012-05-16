use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

#########################

my $zs = Zonestat->new('examples/config');
ok( defined( $zs ), 'Object can be created.' );
ok( $zs->cget( qw[couchdb url] ) eq "http://127.0.0.1:5984/", 'Default config data is there.' );
$zs = Zonestat->new( test => 'data' );
ok( $zs->cget( 'test' ) eq 'data', 'Can set defaults.' );

done_testing;
