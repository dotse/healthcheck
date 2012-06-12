use Test::More;
use lib 't/lib';

BEGIN{
    use_ok('Zonestat');
    use_ok('Zonestat::Collect::Whatweb');
}

my $zs = new_ok(Zonestat => ['t/config/Config']);

my ($name, $data) = Zonestat::Collect::Whatweb->collect('iis.se', $zs);

is($name, 'whatweb');
is(scalar(@$data), 2);
is($data->[1]{plugins}{Charset}{string}[0], 'UTF-8');

done_testing;
