package Zonestat::Collect;

use 5.008008;
use strict;
use utf8;
use warnings;

use base 'Zonestat::Common';
use Zonestat::Util;

use Module::Find 'useall';
use Net::DNS;
use Try::Tiny;
use Time::HiRes 'time';

our $debug = 0;

my @plugins = useall Zonestat::Collect;

our $VERSION = '0.1';

sub for_domain {
    my $self   = shift;
    my $domain = shift;
    my %res    = (
        domain => $domain,
        start  => time(),
    );

    foreach my $p (@plugins) {
        print STDERR "About to call $p\n" if $debug;
        try {
            my @results = $p->collect($domain, $self);
            while (@results) {
                my ($k, $v) = splice(@results, 0, 2);
                $res{$k} = $v;
            } 
            } catch {die $_ if $debug};
    }

    $res{finish} = time();

    return \%res;
}

# This methods is too slow to be useful, and only included here if we ever
# want to use it for some special purpose.
## no critic (Modules::RequireExplicitInclusion)
# No, we should not include Net::DNS::Resolver ourselves, that's not how it works.
sub kaminsky_check {
    my $self = shift;
    my $addr = shift;

    # https://www.dns-oarc.net/oarc/services/porttest
    my $res = Net::DNS::Resolver->new(
        nameservers => [$addr],
        recurse     => 1,
    );
    my $p = $res->query( 'porttest.dns-oarc.net', 'IN', 'TXT', $addr );

    if ( defined( $p ) and $p->header->ancount > 0 ) {
        my $r = ( grep { $_->type eq 'TXT' } $p->answer )[0];
        if ( $r ) {
            my ( $verdict ) = $r->txtdata =~ m/ is ([A-Z]+):/;
            $verdict ||= 'UNKNOWN';
            return $verdict;
        }
    }

    return "UNKNOWN";
}

1;

=head1 NAME

Zonestat::Collect - Module that collects data about a domain and returns it as a reference to a nested hash.

=head1 SYNOPSIS

 my $href = Zonestat->new->collect->for_domain("example.org")
 
=head1 DESCRIPTION

The hashref returned from the C<for_domain> method contains a number of sections. They look as follows.

=over
 
=item dnscheck

Under this key is a cleaned-up version of the exported log output from
L<DNSCheck>. It's a reference to a list containing references to hashes for
log entries. Each hash has the keys C<timestamp>, C<level>, C<tag> and
C<args>. The first three are simply the respective values from DNSCheck, the
last is a reference to a list with the arguments for the tag.

=item dkim

Under this key is a hash with three keys. The first is C<dkim>, which holds
data from the domain's _adsp._domainkey resource records, if one exists. The
second is C<spf_real>, which holds data from the domain's SPF record, if one
exists. And the final one is C<spf_transitionary>, which is the contents of an
SPF-formatted TXT record, if one exists.

=item whatweb

Under this key output from WhatWeb is stored. It's not further used at this
time.

=item mailservers

This is a list of hashes, each one holding data for a server pointed to by an
MX record for the domain. In these hashes are keys C<name> with the DNS name
for it, C<banner> with the SMTP banner message it gave and C<starttls> which
has the value 1 if the server announced STARTTLS capability and 0 otherwise.
If C<starttls> is true, it also has the keys C<sslscan> holding the results
from an sslscan run on the server (see entry below for format of that data)
and a key C<evaluation> with a brief evaluation of that data.

=item sslscan_web

This is a reference to a hash with three keys. The first is C<name>, and holds
the DNS name for the scanned server. The second is C<data> and holds a hash
that is a literal translation of the XML output from the L<sslscan> program
ran with the gathered domain's "www." name at port 443. The third key is
C<evaluation>, and is a hash with a brief evaluation of the cryptographic
quality of the scanned SSL server.

=item pageanalyze

This is a reference to a hash with two keys, C<http> and C<https>. They
contain the results from running L<pageanalyzer> at the domain's "www." name
with the respective protocols. The results are hashes with a literal
translation of the output from L<pageanalyzer>'s JSON mode.

=item webinfo

Like the previous key, this is a reference to a hash with C<http> and C<https>
keys. Each of those are also references to hashes, with the following keys.

=over

=item type

A short string describing the webserver software, detected by running a set of
regexps on the HTTP response Server header field. If none of the regexps
matched, this field will be C<Unknown> and the following one undefined.

=item version

The version of the webserver software, also extracted from the Server header field.

=item raw_type

The unprocessed content of the Server header field.

=item https

A boolean value indicating if the information was gathered over HTTPS or not.

=item url

The URL the information was gathered from.

=item response_code

The HTTP response code received.

=item content_type

The MIME type the server claimed the content is.

=item charset

If the content was of a type with a sub-specified character encoding, this is
the name of the encoding. Note that this is nothing but what the server
claimed, and need not be anything resembling the name of a proper character
encoding!

=item content_length

The value of the C<Content-Length> header field. 

=item redirect_count

The number of times the HTTP library followed redirects before it finally got
a response.

=item redirect_urls

A list of the URLs in the chain of redirects.

=item ending_tld

The top-level domain of the host part in the URL of the final step of the
redirect chain.

=item robots_txt

A boolean value indicting if this server returned something for the path
C</robots.txt>.

=item ip

The IP address that the content was finally fetched from, if that information
was recorded by the L<LWP::UserAgent> object in a form this code understands.
This may not work with future versions of L<LWP>.

=item issuer

The issuer field of the server SSL certificate, for HTTPS connections.

=back

=item geoip

This is a reference to a list of hashes, each giving GeoIP information about a
particular server. The hashes have the following keys.

=over

=item address

The IP address that was looked up.

=item asn

A list of ASN numbers in which the address above is announced.

=item type

The type of the server. Can be one of C<nameserver>, C<mailserver> or C<webserver>.

=item country

The name of the country.

=item code

The two-letter ISO code for the country.

=item city

The name of the city.

=item longitude

The longitude of the IP address' location.

=item latitude

Its latitude.

=item name

The server's name.

=back

=back

