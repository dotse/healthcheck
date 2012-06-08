use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

#########################

my $zs = new_ok('Zonestat'  => ['t/config/Config']);
my $asd = $zs->asdata();

isa_ok($asd, 'Zonestat::DB::Asdata');

is($asd->asn2name(10026), 'PACNET');

done_testing();