use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

my $zs = new_ok('Zonestat'  => ['t/config/Config']);
my $q = $zs->queue;

is($q->length, 0, 'Nothing in the queue.');

done_testing();