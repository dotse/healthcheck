package Zonestat::Mason;

use warnings;
use strict;

use HTML::Mason::ApacheHandler;

{

    package HTML::Mason::Commands;
    use CGI;
    use Zonestat;
}

my $ah = HTML::Mason::ApacheHandler->new(
    comp_root => '/Users/cdybedahl/Clients/IIS/zonestat/Zonestat/web',
    data_dir  => '/var/tmp/mason'
);

sub handler {
    my ($r) = @_;

    my $ctype = $r->content_type;

    return -1
      if ($ctype and $ctype !~ m|^text/|); # Only handle requests for text data.
    return $ah->handle_request($r);
}

1;
