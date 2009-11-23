package Zonestat::Mason;

use warnings;
use strict;

use HTML::Mason::ApacheHandler;
use Zonestat::WebApp;

{

    package HTML::Mason::Commands;
    use CGI;
    use Zonestat;
    use DNSCheck;
    use Apache2::Request;
    use Text::CSV_XS;
    use Data::Dumper;
    our $zs = Zonestat->new('/opt/local/share/dnscheck/site_config.yaml');
    our $dc = DNSCheck->new;
}

my $ah = MasonX::WebApp::ApacheHandler->new(
    comp_root   => '/Users/called/Clients/IIS/zonestat/Zonestat/web',
    data_dir    => '/var/tmp/mason',
    args_method => 'mod_perl',

    # request_class          => 'MasonX::Request::WithApacheSession',
    allow_globals => [qw[$zs $dc $app]],
);

sub handler {
    my ($r)  = @_;
    my $apr  = Apache2::Request->new($r);
    my $args = $ah->request_args($apr);
    my $app = Zonestat::WebApp->new(apache_req => $apr, args => $args);
    local $HTML::Mason::Commands::app = $app;
    $app->MasonGlobalName('$app');

    return $app->abort_status if $app->aborted;

    my $ctype = $r->content_type;

    return -1
      if ($ctype and $ctype !~ m|^text/|); # Only handle requests for text data.
    my $return = eval { $ah->handle_request($r) };
    my $err = $@;

    $app->clean_session if $app->UseSession;

    die $err if $err;

    return $return;
}

1;
