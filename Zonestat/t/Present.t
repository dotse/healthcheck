use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

#########################

my $zs = new_ok( 'Zonestat' => ['t/config/Config'] );
is( $zs->cget( qw[couchdb dbprefix] ), 'zstat' );

my $p = $zs->present;
isa_ok( $p, 'Zonestat::Present' );

is( $p->total_tested_domains( 1 ), 5, '5 tested domains.' );

is_deeply(
    { $p->number_of_domains_with_message( 'ERROR', 1 ) },
    {
        '1' => {
            'NAMESERVER:NO_TCP' => 2,
            'NAMESERVER:NO_UDP' => 2
        }
    },
    'Number of domains with message, level error'
);

is_deeply(
    { $p->number_of_servers_with_software( 0, 1 ) },
    {
        '1' => {
            'Apache'        => 2,
            'Microsoft IIS' => 1,
            'Unknown'       => 2
        }
    },
    'Server types.'
);

is_deeply( { $p->webservers_by_responsecode( 0, 1 ) }, { '1' => { '200' => 5 } }, 'By responsecode' );

is_deeply( { $p->webservers_by_contenttype( 0, 1 ) }, { '1' => { 'text/html' => 5 } }, 'By content type' );

is_deeply( { $p->webservers_by_charset( 0, 1 ) }, { '1' => { 'utf-8' => 4, 'iso-8859-1' => 1 } }, 'By character set' );

is_deeply([$p->all_domainsets], ['testset'], 'All domainset names');

is_deeply({$p->tests_with_max_severity($zs->testrun(1))}, {1 => {'ERROR' => 2, 'NOTICE' => 2, 'WARNING' => 1}}, 'Maximum severity counts');

done_testing;
