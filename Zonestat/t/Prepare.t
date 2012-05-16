use Test::More;
BEGIN { use_ok( 'Zonestat'  => ['t/Config']) }

#########################

my $p = Zonestat->new->prepare;
ok( defined( $p ) );
ok( ref( $p ) eq 'Zonestat::Prepare' );

done_testing;