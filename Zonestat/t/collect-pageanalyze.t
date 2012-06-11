use Test::More;
use lib 't/lib';

BEGIN{
    use_ok('Zonestat');
    use_ok('Zonestat::Collect::Pageanalyze');
}

my $zs = new_ok(Zonestat => ['t/config/Config']);

my ($name, $data) = Zonestat::Collect::Pageanalyze->collect('iis.se', $zs);

is($name, 'pageanalyze');
ok($data->{http} and $data->{http}{summary});
ok($data->{https} and $data->{https}{summary});
is($data->{http}{summary}{total_bytes}, 909228);
is($data->{https}{summary}{total_bytes}, 909228);

done_testing;