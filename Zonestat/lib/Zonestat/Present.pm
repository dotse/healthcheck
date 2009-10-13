package Zonestat::Present;

use 5.008008;
use strict;
use warnings;

use base 'Zonestat::Common';

our $VERSION = '0.01';

sub total_tested_domains {
    my $self = shift;
    my $tr   = shift;

    if (defined($tr)) {
        $tr = $tr->tests;
    } else {
        $tr = $self->dbx('Tests');
    }

    return $tr->search(
        {},
        {
            columns  => ['domain'],
            distinct => 1
        }
    )->count;
}

sub lame_delegated_domains {
    my $self = shift;
    my ($ds) = @_;

    if (defined($ds)) {
        $ds = $ds->tests->search_related('results', {});
    } else {
        $ds = $self->dbx('Results');
    }
    return $ds->search(
        { 'message' => 'NAMESERVER:NOT_AUTH' },
        { 'columns' => [qw(test_id)], 'distinct' => 1 }
    )->count;
}

sub number_of_domains_with_message {
    my $self  = shift;
    my $level = shift;
    my @trs   = @_;
    my %res;

    foreach my $tr (@trs) {
        my $mr = $tr->search_related('tests', {})->search_related(
            'results',
            { level    => $level },
            { group_by => ['message'] }
        );
        while (my $m = $mr->next) {
            $res{ $m->message }{ $tr->id } =
              $tr->search_related('tests', {})->search_related(
                'results',
                { message  => $m->message },
                { group_by => ['test_id'] }
              )->count;
        }
    }

    return %res;
}

sub number_of_servers_with_software {
    my $self = shift;
    return $self->webservers_by_field('type', @_);
}

sub webservers_by_field {
    my $self = shift;
    my ($field, $https, @tr) = @_;
    my %res;

    foreach my $s (@tr) {
        my @data = $s->search_related(
            'webservers',
            { https => ($https ? 1 : 0) },
            {
                select   => [$field, { count => '*' }],
                as       => [$field, 'count'],
                group_by => [$field],
                order_by => ['count(*) DESC'],
            }
        )->all;
        foreach my $row (@data) {
            $res{ $row->get_column($field) }{ $s->id } =
              $row->get_column('count');
        }
    }

    return %res;
}

sub webservers_by_responsecode {
    my $self = shift;
    return $self->webservers_by_field('response_code', @_);
}

sub webservers_by_contenttype {
    my $self = shift;
    return $self->webservers_by_field('content_type', @_);
}

sub webservers_by_charset {
    my $self = shift;
    return $self->webservers_by_field('charset', @_);
}

sub unknown_server_strings {
    my $self = shift;
    my @ds   = @_;
    my %res;

    foreach my $ds (@ds) {
        $res{ $ds->id } = [
            map { $_->raw_type } $ds->search_related(
                'webservers',
                { type => 'Unknown' },
                {
                    columns  => ['raw_type'],
                    distinct => 1,
                    order_by => ['raw_type']
                }
              )->all
        ];
    }

    return %res;
}

sub all_dnscheck_tests {
    my $self = shift;
    my $ds   = shift;

    my $s;

    if (defined($ds)) {
        $s = $ds->tests;
    } else {
        $s = $self->dbx('Tests');
    }

    return $s->search({}, { order_by => ['domain'] });
}

sub all_domainsets {
    my $self = shift;

    my $s = $self->dbx('Domainset');
    return $s->search({}, { order_by => ['name'] });
}

sub tests_with_max_severity {
    my $self = shift;
    my @ds   = @_;

    my %res;

    foreach my $ds (@ds) {
        $res{critical}{ $ds->id } =
          $ds->search_related('tests', { count_critical => { '>', 0 } })->count;
        $res{error}{ $ds->id } =
          $ds->search_related('tests',
            { count_critical => 0, count_error => { '>', 0 } })->count;
        $res{warning}{ $ds->id } = $ds->search_related(
            'tests',
            {
                count_critical => 0,
                count_error    => 0,
                count_warning  => { '>', 0 }
            }
        )->count;
        $res{notice}{ $ds->id } = $ds->search_related(
            'tests',
            {
                count_critical => 0,
                count_error    => 0,
                count_warning  => 0,
                count_notice   => { '>', 0 }
            }
        )->count;
        $res{info}{ $ds->id } = $ds->search_related(
            'tests',
            {
                count_critical => 0,
                count_error    => 0,
                count_warning  => 0,
                count_notice   => 0,
                count_info     => { '>', 0 }
            }
        )->count;
    }

    return %res;
}

sub domainset_being_tested {
    my $self = shift;
    my $ds   = shift;

    return (
        $ds->testruns->search_related('tests', { end => undef })->count > 0);
}

sub top_foo_servers {
    my $self   = shift;
    my $kind   = uc(shift);
    my $tr     = shift;
    my $number = shift || 25;

    return $self->dbx('Server')->search(
        { kind => $kind, run_id => $tr->id },
        {
            select => [
                qw[ip latitude longitude country code city asn],
                { count => '*' }
            ],
            as => [qw[ip latitude longitude country code city asn], 'count'],
            group_by => [qw[ip latitude longitude country code city asn]],
            order_by => ['count(*) DESC'],
            rows     => $number
        }
    )->all;
}

sub google_mapchart_url {
    my $self = shift;
    my ($trid, $kind) = @_;
    my $tr = $self->dbx('Testrun')->find($trid);

    my %data =
      map { $_->code, $_->get_column('count') }
      grep { $_->code } $self->dbx('Server')->search(
        { kind => uc($kind), run_id => $tr->id },
        {
            select   => [qw[code], { count => '*' }],
            as       => [qw[code], 'count'],
            group_by => [qw[code]],
            order_by => ['count(*) DESC'],
        }
      )->all;

    my $max = 0;
    foreach my $v (values %data) {
        $max = $v if $v > $max;
    }

    foreach my $k (keys %data) {
        $data{$k} = sprintf "%0.1f", 100 * ($data{$k} / $max);
    }

    my $chd  = 'chd=t:' . join ',', values %data;
    my $chld = 'chld=' . join '',   keys %data;

    return
'http://chart.apis.google.com/chart?chs=440x220&cht=t&chtm=world&chco=FFFFFF,CCFFCC,00FF00&chf=bg,s,EAF7FE&'
      . $chld . '&'
      . $chd;
}

sub top_dns_servers {
    my $self = shift;
    return $self->top_foo_servers('DNS', @_);
}

sub top_http_servers {
    my $self = shift;
    return $self->top_foo_servers('HTTP', @_);
}

sub top_smtp_servers {
    my $self = shift;
    return $self->top_foo_servers('SMTP', @_);
}

sub nameservers_per_asn {
    my $self = shift;
    my $ipv6 = shift;
    my @tr   = @_;
    my %res;

    foreach my $t (@tr) {
        foreach my $r (
            $self->dbx('Server')->search(
                {
                    kind   => 'DNS',
                    run_id => $t->id,
                    ipv6   => $ipv6,
                    asn    => { '!=', undef }
                },
                {
                    select   => [qw[asn], { count => '*' }],
                    as       => [qw[asn], 'count'],
                    group_by => [qw[asn]],
                    order_by => ['count(*) DESC'],
                }
            )->all
          )
        {
            $res{ $r->asn }{ $t->id } = $r->get_column('count');
        }
    }

    return %res;
}

sub ipv6_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;

    my $all = $tr->domainset->domains->count;
    my $v6 =
      $tr->search_related('servers', { ipv6 => 1 })
      ->search_related('domain', {}, { group_by => ['domain'] })->count;

    return (100 * ($v6 / $all), $v6);
}

sub multihome_percentage_for_testrun {
    my $self = shift;
    my ($tr, $ipv6) = @_;

    my $message;
    if ($ipv6) {
        $message = 'CONNECTIVITY:V6_ASN_COUNT_OK';
    } else {
        $message = 'CONNECTIVITY:ASN_COUNT_OK';
    }

    my $all = $tr->tests->count;
    my $ok =
      $tr->search_related('tests', {})
      ->search_related('results', { message => $message })->count;

    return (100 * ($ok / $all), $ok);
}

sub dnssec_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;

    my $all = $tr->tests->count;
    my $ds =
      $tr->search_related('tests', {})
      ->search_related('results', { message => 'DNSSEC:DS_FOUND' })->count;

    return (100 * ($ds / $all), $ds);
}

sub recursing_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;

    my $all = $tr->tests->count;
    my $ds = $tr->search_related('tests', {})->search_related(
        'results',
        { message  => 'NAMESERVER:RECURSIVE' },
        { group_by => ['test_id'] }
    )->count;

    return (100 * ($ds / $all), $ds);
}

sub adsp_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;

    my $all  = $tr->tests->count;
    my $adsp = $self->dbx('Mailserver')->search(
        {
            run_id => $tr->id,
            adsp   => { '!=', undef }
        },
        { group_by => ['domain_id'] }
    )->count;

    return (100 * ($adsp / $all), $adsp);
}

sub starttls_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;

    my $all      = $tr->tests->count;
    my $starttls = $self->dbx('Mailserver')->search(
        { run_id   => $tr->id, starttls => 1 },
        { group_by => ['domain_id'] }
    )->count;

    return (100 * ($starttls / $all), $starttls);
}

sub nameserver_count {
    my $self = shift;
    my ($tr, $ipv6) = @_;

    my $divider = $ipv6 ? '%:%' : '%.%';

    return $tr->search_related('tests', {})->search_related(
        'results',
        {
            message => 'DNS:NAMESERVER_FOUND',
            arg0    => {
                '!=' => '',
                '='  => \'domain',
            },
            arg3 => { -like => [$divider] },
        },
        {
            columns  => [qw(arg3)],
            distinct => 1
        }
    )->count;
}

sub mailservers_in_sweden {
    my $self = shift;
    my ($tr, $ipv6) = @_;

    my $ms = $tr->search_related('servers', { kind => 'SMTP', ipv6 => $ipv6 })->count;
    my $se =
      $tr->search_related('servers', { kind => 'SMTP', ipv6 => $ipv6, code => 'SE' })->count;

    if ($ms > 0) {
        return 100 * ($se / $ms);
    } else {
        return 'N/A';
    }
}

1;
__END__

=head1 NAME

Zonestat::Present - present gathered statistics

=head1 SYNOPSIS

  use Zonestat::Present;

=head1 DESCRIPTION


=head1 SEE ALSO

L<Zonestat>.

=head1 AUTHOR

Calle Dybedahl, E<lt>calle@init.seE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Calle Dybedahl

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.9 or,
at your option, any later version of Perl 5 you may have available.


=cut
