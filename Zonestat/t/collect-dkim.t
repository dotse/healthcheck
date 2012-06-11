use Test::More;
use lib 't/lib';

# use MockBootstrap 'collect-dkim';
use MockResolver 'collect-dkim';

BEGIN{
    use_ok('Zonestat');
    use_ok('Zonestat::Collect::DKIM');
}

my $zs = new_ok(Zonestat => ['t/config/Config']);

my ($name, $data) = Zonestat::Collect::DKIM->collect('iis.se', $zs);

is($name, 'dkim');
is($data->{adsp}, 'dkim=unknown');
is($data->{spf_real}, undef);
is($data->{spf_transitionary}, 'v=spf1 ip4:212.247.204.0/24 ip4:212.247.7.128/25 ip4:212.247.8.128/25 ip4:212.247.3.0/25 ip4:212.247.14.32/28 ip4:212.247.165.16/28 ip4:212.247.206.0/24 ip4:91.226.36.0/23 ip6:2a00:801:f0:211::147 ip6:2a00:801:f0:106::38 mx ~all');

done_testing;