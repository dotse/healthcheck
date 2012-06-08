use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

#########################

my $zs = new_ok('Zonestat'  => ['t/config/Config']);
is($zs->cget(qw[couchdb dbprefix]), 'zstat');

my $p = $zs->present;
isa_ok( $p, 'Zonestat::Present' );

# is($p->total_tested_domains, 0, 'No tested domains.');

done_testing;