package Zonestat::Mason;

use warnings;
use strict;

use HTML::Mason::ApacheHandler;

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

my $ah = HTML::Mason::ApacheHandler->new(
    comp_root     => '/Users/cdybedahl/Clients/IIS/zonestat/Zonestat/web',
    data_dir      => '/var/tmp/mason',
    args_method   => 'mod_perl',
    request_class => 'MasonX::Request::WithApacheSession',
    session_cookie_domain  => '.cyberpomo.com',
    session_class          => 'Apache::Session::File',
    session_directory      => '/tmp/sessions/data',
    session_lock_directory => '/tmp/sessions/locks',
    session_use_cookie     => 1,
    allow_globals          => [qw[$zs $dc]],
);

sub handler {
    my ($r) = @_;

    my $ctype = $r->content_type;

    return -1
      if ($ctype and $ctype !~ m|^text/|); # Only handle requests for text data.
    return $ah->handle_request($r);
}

1;
