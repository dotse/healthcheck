package Statweb::Controller::Showstats;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use Data::Dumper;
use Time::HiRes qw[time];
use List::Util qw[max];

=head1 NAME

Statweb::Controller::Showstats - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

my %http_response_code = (
    100 => q{Continue},
    101 => q{Switching Protocols},
    102 => q{Processing},
    200 => q{OK},
    201 => q{Created},
    202 => q{Accepted},
    203 => q{Non-Authoritative Information},
    204 => q{No Content},
    205 => q{Reset Content},
    206 => q{Partial Content},
    207 => q{Multi-Status},
    226 => q{IM Used},
    300 => q{Multiple Choices},
    301 => q{Moved Permanently},
    302 => q{Found},
    303 => q{See Other},
    304 => q{Not Modified},
    305 => q{Use Proxy},
    306 => q{Reserved},
    307 => q{Temporary Redirect},
    400 => q{Bad Request},
    401 => q{Unauthorized},
    402 => q{Payment Required},
    403 => q{Forbidden},
    404 => q{Not Found},
    405 => q{Method Not Allowed},
    406 => q{Not Acceptable},
    407 => q{Proxy Authentication Required},
    408 => q{Request Timeout},
    409 => q{Conflict},
    410 => q{Gone},
    411 => q{Length Required},
    412 => q{Precondition Failed},
    413 => q{Request Entity Too Large},
    414 => q{Request-URI Too Long},
    415 => q{Unsupported Media Type},
    416 => q{Requested Range Not Satisfiable},
    417 => q{Expectation Failed},
    422 => q{Unprocessable Entity},
    423 => q{Locked},
    424 => q{Failed Dependency},
    426 => q{Upgrade Required},
    500 => q{Internal Server Error},
    501 => q{Not Implemented},
    502 => q{Bad Gateway},
    503 => q{Service Unavailable},
    504 => q{Gateway Timeout},
    505 => q{HTTP Version Not Supported},
    506 => q{Variant Also Negotiates (Experimental)},
    507 => q{Insufficient Storage},
    510 => q{Not Extended},
);

sub index : Local : Args(0) {
    my ( $self, $c ) = @_;

    $c->detach( 'default' );
}

sub default : Path : Args(0) {
    my ( $self, $c ) = @_;

    my @trs = @{ $c->stash->{trs} };
    my $name;
    my %data;
    my $p = $c->{zs}->present;

    if ( @trs == 1 ) {
        $name = $trs[0]->name;
    }
    else {
        $name = scalar( @trs ) . ' testruns';
    }

    $data{names} = [ map { $_->domainset . ' ' . $_->name } @trs ];

    $data{ipv6domains} = [ map { sprintf "%0.2f%% (%d)", $p->ipv6_percentage_for_testrun( $_->id ) } @trs ];

    $data{ipv4as} = [ map { sprintf "%0.2f%% (%d)", $p->multihome_percentage_for_testrun( $_->id, 0 ) } @trs ];

    $data{ipv6as} = [ map { sprintf "%0.2f%% (%d)", $p->multihome_percentage_for_testrun( $_->id, 1 ) } @trs ];

    $data{dnssec} = [ map { sprintf "%0.2f%% (%d)", $p->dnssec_percentage_for_testrun( $_->id ) } @trs ];

    $data{recursive} = [ map { sprintf "%0.2f%% (%d)", $p->recursing_percentage_for_testrun( $_->id ) } @trs ];

    $data{adsp} = [ map { sprintf "%0.2f%% (%d)", $p->adsp_percentage_for_testrun( $_->id ) } @trs ];

    $data{spf} = [ map { sprintf "%0.2f%% (%d)", $p->spf_percentage_for_testrun( $_->id ) } @trs ];

    $data{starttls} = [ map { sprintf "%0.2f%% (%d)", $p->starttls_percentage_for_testrun( $_->id ) } @trs ];

    $data{mailv4} = [ map { sprintf "%0.2f%% (%d)", $p->mailservers_in_sweden( $_->id, 0 ) } @trs ];

    $data{mailv6} = [ map { sprintf "%0.2f%% (%d)", $p->mailservers_in_sweden( $_->id, 1 ) } @trs ];

    $data{tested} = [ map { $_->test_count } @trs ];

    $data{distinctv4} = [ map { $p->nameserver_count( $_->id, 0 ) } @trs ];

    $data{distinctv6} = [ map { $p->nameserver_count( $_->id, 1 ) } @trs ];

    $data{http} = [ map { $p->webserver_count( $_->id, 0 ) } @trs ];

    $data{https} = [ map { $p->webserver_count( $_->id, 1 ) } @trs ];

    $c->stash(
        {
            template  => 'showstats/index.tt',
            pagetitle => $name,
            data      => \%data,
        }
    );
}

sub webpages_software : Private {
    my ( $self, $c ) = @_;
    my @trs = map { $_->id } @{ $c->stash->{trs} };
    my $p = $c->{zs}->present;

    $c->stash->{data}{software} = {
        http  => _reshuffle( \@trs, $p->number_of_servers_with_software( 0, @trs ) ),
        https => _reshuffle( \@trs, $p->number_of_servers_with_software( 1, @trs ) ),
    };
}

sub webpages_response : Private {
    my ( $self, $c ) = @_;
    my @trs = map { $_->id } @{ $c->stash->{trs} };
    my $p = $c->{zs}->present;

    $c->stash->{data}{response} = {
        http  => _reshuffle( \@trs, $p->webservers_by_responsecode( 0, @trs ) ),
        https => _reshuffle( \@trs, $p->webservers_by_responsecode( 1, @trs ) ),
    };
}

sub webpages_content : Private {
    my ( $self, $c ) = @_;
    my @trs = map { $_->id } @{ $c->stash->{trs} };
    my $p = $c->{zs}->present;

    $c->stash->{data}{content} = {
        http  => _reshuffle( \@trs, $p->webservers_by_contenttype( 0, @trs ) ),
        https => _reshuffle( \@trs, $p->webservers_by_contenttype( 1, @trs ) ),
    };
}

sub webpages_charset : Private {
    my ( $self, $c ) = @_;
    my @trs = map { $_->id } @{ $c->stash->{trs} };
    my $p = $c->{zs}->present;

    $c->stash->{data}{charset} = {
        http  => _reshuffle( \@trs, $p->webservers_by_charset( 0, @trs ) ),
        https => _reshuffle( \@trs, $p->webservers_by_charset( 1, @trs ) ),
    };
}

sub webpages_pageanalyzer : Private {
    my ( $self, $c ) = @_;
    my @trs = @{ $c->stash->{trs} };
    my $p   = $c->{zs}->present;

    $c->stash->{pa} = $p->pageanalyzer_summary( map { $_->id } @trs );
}

sub webpages : Local : Args(0) {
    my ( $self, $c ) = @_;
    my @trs = @{ $c->stash->{trs} };
    my $db  = $c->{zs}->dbproxy( 'zonestat' );
    my $name;
    my $p = $c->{zs}->present;

    if ( @trs == 1 ) {
        $name = $trs[0];
    }
    else {
        $name = scalar( @trs ) . ' testruns';
    }

    $c->stash(
        {
            template  => 'showstats/webpages.tt',
            pagetitle => $name,
            http_code => \%http_response_code,
            sizes     => {
                http  => [ map { $db->server_web( key => 0 + $_->id )->{rows}[0]{value}{http} } @trs ],
                https => [ map { $db->server_web( key => 0 + $_->id )->{rows}[0]{value}{https} } @trs ],
            },
            trs    => \@trs,
            titles => {
                software => 'Type',
                response => 'Response Code',
                content  => 'Content-Type',
                charset  => 'Character Encoding',
            },
        }
    );

    $c->forward( 'webpages_software' );
    $c->forward( 'webpages_response' );
    $c->forward( 'webpages_content' );
    $c->forward( 'webpages_charset' );
    $c->forward( 'webpages_pageanalyzer' );
}

sub _reshuffle {
    my ( $trs, %res ) = @_;
    my @out;

    my @ids        = @$trs;
    my $kid        = $ids[0];
    my @categories = sort { $res{$kid}{$b} <=> $res{$kid}{$a} } keys %{ $res{$kid} };

    foreach my $c ( @categories ) {
        push @out, [ $c, map { $_ ? $_ : 0 } map { $res{$_}{$c} } @ids ];
    }

    return \@out;
}

sub dnscheck : Local : Args(0) {
    my ( $self, $c ) = @_;
    my @trs = @{ $c->stash->{trs} };

    my %sizes = map { $_->id, $_->test_count } @trs;
    my $name;
    my %data;
    my $p        = $c->{zs}->present;
    my %errors   = $p->number_of_domains_with_message( 'ERROR', map { 0 + $_->id } @trs );
    my %warnings = $p->number_of_domains_with_message( 'WARNING', map { 0 + $_->id } @trs );
    my @eorder =
      sort { $errors{ $trs[0]->id }{$b} <=> $errors{ $trs[0]->id }{$a} }
      keys %{ $errors{ $trs[0]->id } };
    my @worder =
      sort { $warnings{ $trs[0]->id }{$b} <=> $warnings{ $trs[0]->id }{$a} }
      keys %{ $warnings{ $trs[0]->id } };
    my %descriptions;

    foreach my $m ( @eorder, @worder ) {
        $descriptions{$m} = $p->lookup_desc( $m );
    }

    # "Message band" tables.
    my %band = $p->message_bands( map { $_->id } @trs );

    # "Max severity" table
    my %severity = $p->tests_with_max_severity( @trs );

    if ( @trs == 1 ) {
        $name = $trs[0]->name;
    }
    else {
        $name = scalar( @trs ) . ' testruns';
    }

    $data{names} = [ map { $_->domainset . ' ' . $_->name } @trs ];

    $c->stash(
        {
            template     => 'showstats/dnscheck.tt',
            pagetitle    => $name,
            data         => \%data,
            errors       => \%errors,
            warnings     => \%warnings,
            eorder       => \@eorder,
            worder       => \@worder,
            trs          => \@trs,
            descriptions => \%descriptions,
            band         => \%band,
            severity     => \%severity,
            sizes        => \%sizes,
        }
    );
}

sub servers : Local : Args(0) {
    my ( $self, $c ) = @_;
    my @trs = @{ $c->stash->{trs} };

    my $name;
    my %data;
    my $p = $c->{zs}->present;

    if ( @trs == 1 ) {
        $name = $trs[0];
    }
    else {
        $name = scalar( @trs ) . ' testruns';
    }

    $data{names} = { map { $_->id, $_->name } @trs };
    $data{trs} = \@trs;

    foreach my $kind ( qw[nameserver mailserver webserver] ) {
        foreach my $tr ( @trs ) {
            my @s = $p->top_foo_servers( $kind, $tr->id, 25 );
            $data{$kind}{ $tr->id } = [
                map {
                    {    # 0:count, 1:address, 2:latitude, 3:longitude, 4:country, 5:code, 6:city, 7:asn
                        reverse    => $_->[1],
                          count    => $_->[0],
                          location => join( ', ', grep { $_ } ( $_->[6], $_->[4] ) ),
                          geourl => ( $_->[2] and $_->[3] )
                          ? sprintf( 'http://maps.google.com/maps?q=%02.2f+%02.2f', $_->[2], $_->[3] )
                          : ''
                    }
                  } @s
            ];
        }
    }

    my %ns_per_asn_v4 = $p->nameservers_per_asn( 0, map { $_->id } @trs );
    my %ns_per_asn_v6 = $p->nameservers_per_asn( 1, map { $_->id } @trs );
    my %asnames;
    my $asn = $c->model( 'DB' )->asdata;

    foreach my $tr ( @trs ) {
        foreach my $as ( keys %{ $ns_per_asn_v4{ $tr->id } }, keys %{ $ns_per_asn_v6{ $tr->id } } ) {
            my $n = $asn->asn2name( $as );
            if ( defined( $n ) ) {
                $asnames{$as} = $n;
            }
            else {
                $asnames{$as} = 'No name';
            }
        }
    }
    my @asv4order = sort { $ns_per_asn_v4{ $trs[0]->id }{$b} <=> $ns_per_asn_v4{ $trs[0]->id }{$a} } keys %{ $ns_per_asn_v4{ $trs[0]->id } };
    splice @asv4order, 20 if @asv4order > 20;
    my @asv6order = sort { $ns_per_asn_v6{ $trs[0]->id }{$b} <=> $ns_per_asn_v6{ $trs[0]->id }{$a} } keys %{ $ns_per_asn_v6{ $trs[0]->id } };
    splice @asv6order, 20 if @asv6order > 20;

    $c->stash(
        {
            template      => 'showstats/servers.tt',
            pagetitle     => $name,
            trs           => \@trs,
            data          => \%data,
            ns_per_asn_v4 => \%ns_per_asn_v4,
            ns_per_asn_v6 => \%ns_per_asn_v6,
            asv4order     => \@asv4order,
            asv6order     => \@asv6order,
            asnames       => \%asnames,
        }
    );
}

sub view_by_level : Local : Args(2) {
    my ( $self, $c, $level, $trid ) = @_;
    my $tr = $c->model( 'DB::Testrun' )->find( $trid );
    my @tests = $tr->search_related( 'tests', { 'count_' . lc( $level ) => { '>', 0 } } )->all;

    $c->stash(
        {
            template => 'showstats/view_by_level.tt',
            tr       => $tr,
            level    => $level,
            tests    => \@tests,
        }
    );
}

sub auto : Private {
    my ( $self, $c ) = @_;
    my $db = $c->model( 'DB::Testrun' );

    $c->stash(
        {
            trs => [
                sort   { $b->test_count <=> $a->test_count }
                  grep { $_ }
                  map  { $c->model( 'DB' )->testrun( $_ ) }
                  keys %{ $c->session->{testruns} }
            ]
        }
    );

    return 1;
}

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
