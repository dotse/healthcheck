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
my @smtp = $p->top_smtp_servers( 1 );
my @http = $p->top_http_servers( 1 );

is_deeply { $p->nameservers_per_asn( 0, 1 ) },
  {
    '1' => {
        '1257'  => 4,
        '1653'  => 1,
        '2119'  => 1,
        '21195' => 2,
        '3301'  => 4,
        '50273' => 2
    }
  },
  'Nameservers per ASN looks OK';

is_deeply { $p->multihome_percentage_for_testrun( 1 ) }, { 100 => 5 }, 'Multihomed percentage looks OK';
is_deeply { $p->ipv6_percentage_for_testrun( 1 ) },      { 60  => 3 }, 'IPv6 percentage looks OK';

is_deeply { $p->dnssec_percentage_for_testrun( 1 ) },    { 80  => 4 }, 'DNSSEC percentage looks OK';
is_deeply { $p->recursing_percentage_for_testrun( 1 ) }, { 0   => 0 }, 'Recursing percentage looks OK';
is_deeply { $p->adsp_percentage_for_testrun( 1 ) },      { 20  => 1 }, 'ADSP percentage looks OK';
is_deeply { $p->spf_percentage_for_testrun( 1 ) },       { 100 => 5 }, 'SPF percentage looks OK';
is_deeply { $p->starttls_percentage_for_testrun( 1 ) },  { 80  => 4 }, 'STARTTLS percentage looks OK';

is( $p->nameserver_count( 1 ), 11, 'Sensible number of nameservers' );
is_deeply( [ $p->mailservers_in_sweden( 1 ) ], [ 58.3333333333333, 14 ], 'Sensible number if Swedish mailservers' );
is( $p->webserver_count( 1 ), 5, 'Sensible number of webservers' );

is_deeply { $p->message_bands( 1 ) },
  {
    '1' => {
        'CRITICAL' => {
            '0'  => 5,
            '1'  => 0,
            '2'  => 0,
            '3+' => 0
        },
        'ERROR' => {
            '0'  => 3,
            '1'  => 0,
            '2'  => 2,
            '3+' => 0
        },
        'WARNING' => {
            '0'  => 4,
            '1'  => 1,
            '2'  => 0,
            '3+' => 0
        }
    }
  },
  'DNSCheck message bands look OK';

is( $p->lookup_desc( 'NAMESERVER:NO_TCP' ), 'The name server failed to answer queries sent over TCP.  This is probably due to the name server not correctly set up or due to misconfgured filtering in a firewall. It is a rather common misconception that DNS does not need TCP unless they provide zone transfers - perhaps the name server administrator is not aware that TCP usually is a requirement.', 'Looked-up message description looks OK' );

is $p->pageanalyzer_summary( 1 )->{1}{external_resources}{total}, 55, 'Pageanalyzer summary structure makes some sort of sense';

is $p->tests_by_level( 'ERROR', 1 )->{1}{'nic.se'}{'ERROR'}, 2, 'Tests by level structure makes some sort of sense';

eval { $p->unknown_server_strings};
like($@, qr/Not ported/, 'Unimplemented method explodes');

eval { $p->all_dnscheck_tests};
like($@, qr/Not ported/, 'Unimplemented method explodes');

eval { $p->domainset_being_tested};
like($@, qr/Not ported/, 'Unimplemented method explodes');

done_testing;
