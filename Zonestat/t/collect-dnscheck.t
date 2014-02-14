use Test::More;
use lib 't/lib';

BEGIN{
    use_ok('Zonestat');
    use_ok('Zonestat::Collect::DNSCheck');
}

my $zs = new_ok(Zonestat => ['t/config/Config']);

# my ($name1, $data1, $name2, $data2, $name3, $data3) = Zonestat::Collect::DNSCheck->collect('iis.se', $zs);

# is($name1, 'dnscheck');
# is($name2, 'mailservers');
# is($name3, 'geoip');
# ok(scalar(@$data1) >= 150, 'enough dnscheck');
# ok(scalar(@$data2) >= 4, 'correct mailservers');
# ok(scalar(@$data3) >= 14, 'correct geoip');

done_testing;
