use Test::More;
BEGIN { use_ok( 'Zonestat' ) }

#########################

my $p = Zonestat->new('t/Config')->prepare;
ok( defined( $p ) );
ok( ref( $p ) eq 'Zonestat::Prepare' );

done_testing;