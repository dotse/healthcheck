use Test::More;
use Test::WWW::Mechanize::Catalyst;

my $mech = Test::WWW::Mechanize::Catalyst->new( catalyst_app => 'Statweb');

$mech->get_ok('/');
$mech->title_like(qr'.SE | H..?lsol..?get i Sverige');
$mech->submit_form_ok({
    form_number => 1,
    fields => {
        username => 'someuser',
        password => 'somepwd'
    }
}, 'Posting login form');
$mech->title_is('Statweb');

done_testing;