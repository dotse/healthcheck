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

is_deeply( [ $p->all_domainsets ], ['testset'], 'All domainset names' );

is_deeply( { $p->tests_with_max_severity( $zs->testrun( 1 ) ) }, { 1 => { 'ERROR' => 2, 'NOTICE' => 2, 'WARNING' => 1 } }, 'Maximum severity counts' );

my @dns = $p->top_dns_servers( 1 );
is( scalar( @dns ), 17, 'Right number of DNS servers' );
is_deeply( $dns[1], [ 2, '194.17.45.54', '56.3667', '13.4832', 'Sweden', 'SE', "Sk\x{c3}\x{83}\x{c2}\x{a5}nes Fagerhult", [ '3301' ] ], 'Sensible content in DNS server list' );

my @smtp = $p->top_smtp_servers( 1 );
is( scalar( @smtp ), 11, 'Right number of SMTP servers.' );
is_deeply( $smtp[0], [ 4, '212.247.7.222', '59.3333', '18.0500', 'Sweden', 'SE', 'Stockholm', [ '1257' ] ], 'Sensible content in SMTP server list' );

my @http = $p->top_http_servers( 1 );
is( scalar( @http ), 4, 'Right number of HTTP servers' );
is_deeply( $http[1], [ 1, '193.11.1.138', '59.3333', '18.0500', 'Sweden', 'SE', 'Stockholm', [ '1653' ] ], 'Sensible content in HTTP list.' );

done_testing;
