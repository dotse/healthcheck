use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

my $zs = new_ok('Zonestat'  => ['t/config/Config']);


done_testing();