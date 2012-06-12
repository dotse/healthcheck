use Test::More;
use lib 't/lib';

BEGIN{
    use_ok('Zonestat');
    use_ok('Zonestat::Collect::Sslscan');
}

my $zs = new_ok(Zonestat => ['t/config/Config']);

my ($name, $data) = Zonestat::Collect::Sslscan->collect('iis.se', $zs);

is($name, 'sslscan_web');
is($data->{data}{ssltest}{certificate}{issuer}, '/C=US/O=Thawte, Inc./CN=Thawte SSL CA');

done_testing;
