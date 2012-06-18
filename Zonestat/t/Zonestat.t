use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

#########################

my $zs = Zonestat->new('examples/config');
ok( defined( $zs ), 'Object can be created.' );
ok( $zs->cget( qw[couchdb url] ) eq "http://127.0.0.1:5984/", 'Default config data is there.' );
$zs = Zonestat->new( test => 'data' );
ok( $zs->cget( 'test' ) eq 'data', 'Can set defaults.' );

isa_ok $zs->collect, 'Zonestat::Collect';

my $data = Zonestat->new('t/config/Config')->collect->for_domain('nic.se');
is(scalar(keys(%$data)), 11, 'Collection returns a reasonable number of keys');

done_testing;
