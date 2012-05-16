use Test::More;
BEGIN { use_ok( 'Zonestat'  => ['t/Config']) }

#########################

my $p = Zonestat->new->present;
ok( defined( $p ) );
ok( ref( $p ) eq 'Zonestat::Present' );

done_testing;