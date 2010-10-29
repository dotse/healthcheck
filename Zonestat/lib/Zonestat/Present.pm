package Zonestat::Present;

use 5.008008;
use strict;
use warnings;

use base 'Zonestat::Common';

use YAML 'LoadFile';
use Config;
use Storable qw[freeze thaw];

our $VERSION = '0.01';

my $locale = LoadFile $Config{siteprefix} . '/share/dnscheck/locale/en.yaml';

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

### FIXME: Special table for DNSSEC problems.

sub number_of_domains_with_message {
    my $self  = shift;
    my $level = shift;
    my @trs   = @_;
    my %res;

    foreach my $tr (@trs) {
        my $key = 'number_of_domains_with_message ' . $level . ' ' . $tr->id;
        unless ($self->chi->is_valid($key)) {
            my %tmp;
            my $mr = $tr->search_related('tests', {})->search_related(
                'results',
                { level    => $level },
                { group_by => ['message'] }
            );
            while (my $m = $mr->next) {
                $tmp{ $m->message } =
                  $tr->search_related('tests', {})->search_related(
                    'results',
                    { message  => $m->message },
                    { group_by => ['test_id'] }
                  )->count;
            }
            $self->chi->set($key, \%tmp);
        }
        my %tmp = %{ $self->chi->get($key) };
        foreach my $m (keys %tmp) {
            $res{$m}{ $tr->id } = $tmp{$m};
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
        my $key =
          'webservers_per_field ' . $field . ' ' . $s->id . ' ' . $https;
        unless ($self->chi->is_valid($key)) {
            $self->chi->set(
                $key,
                [
                    $s->search_related(
                        'webservers',
                        { https => ($https ? 1 : 0) },
                        {
                            select   => [$field, { count => '*' }],
                            as       => [$field, 'count'],
                            group_by => [$field],
                            order_by => ['count(*) DESC'],
                        }
                      )->all
                ]
            );
        }
        foreach my $row (@{ $self->chi->get($key) }) {
            $res{ lc($row->get_column($field)) }{ $s->id } =
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

    my $dbp = $self->dbproxy('zonestat-dset');
    return map { $_->{key} } @{ $dbp->util_set(group => 'true')->{rows} };
}

sub tests_with_max_severity {
    my $self    = shift;
    my $testrun = shift;

    my $dbp = $self->dbproxy('zonestat');
    my $res = $dbp->check_maxseverity(
        startkey => ['' . $testrun, 'A'],
        endkey   => ['' . $testrun, 'Z'],
        group    => 'true'
    )->{rows};

    return map { $_->{key}[1] => $_->{value} } @$res;
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

    my $key = 'top_foo_servers ' . $kind . ' ' . $tr->id . ' ' . $number;

    unless ($self->chi->is_valid($key)) {
        $self->chi->set(
            $key,
            [
                $self->dbx('Server')->search(
                    { kind => $kind, run_id => $tr->id },
                    {
                        select => [
                            qw[ip latitude longitude country code city asn],
                            { count => '*' }
                        ],
                        as => [
                            qw[ip latitude longitude country code city asn],
                            'count'
                        ],
                        group_by =>
                          [qw[ip latitude longitude country code city asn]],
                        order_by => ['count(*) DESC'],
                        rows     => $number
                    }
                  )->all
            ]
        );
    }

    return @{ $self->chi->get($key) };
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
        my $key = 'nameservers_per_asn ' . $t->id . ' ' . $ipv6;
        unless ($self->chi->is_valid($key)) {
            $self->chi->set(
                $key,
                [
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
                ]
            );
        }
        foreach my $r (@{ $self->chi->get($key) }) {
            $res{ $r->asn }{ $t->id } = $r->get_column('count');
        }
    }

    return %res;
}

sub ipv6_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my $key  = "ipv6_percentage_for_testrun " . $tr->id;

    unless ($self->chi->is_valid($key)) {
        my $all = $tr->domainset->domains->count;
        my $v6 =
          $tr->search_related('servers', { ipv6 => 1 })
          ->search_related('domain', {}, { group_by => ['domain'] })->count;

        $self->chi->set($key, [100 * ($v6 / $all), $v6]);
    }
    return @{ $self->chi->get($key) };
}

sub multihome_percentage_for_testrun {
    my $self = shift;
    my ($tr, $ipv6) = @_;
    my $key = "multihome_percentage_for_testrun " . $tr->id . " $ipv6";

    unless ($self->chi->is_valid($key)) {
        my $message;
        if ($ipv6) {
            $message = 'CONNECTIVITY:V6_ASN_COUNT_OK';
        } else {
            $message = 'CONNECTIVITY:ASN_COUNT_OK';
        }

        my $all = $tr->tests->count;
        if ($all > 0) {
            my $ok =
              $tr->search_related('tests', {})
              ->search_related('results', { message => $message })->count;

            $self->chi->set($key, [100 * ($ok / $all), $ok]);
        } else {
            $self->chi->set($key, [qw[N/A N/A]]);
        }
    }
    return @{ $self->chi->get($key) };
}

sub dnssec_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my $key  = "dnssec_percentage_for_testrun " . $tr->id;

    unless ($self->chi->is_valid($key)) {
        my $all = $tr->tests->count;
        if ($all > 0) {
            my $ds =
              $tr->search_related('tests', {})
              ->search_related('results', { message => 'DNSSEC:DS_FOUND' })
              ->count;

            $self->chi->set($key, [100 * ($ds / $all), $ds]);
        } else {
            $self->chi->set($key, [qw[N/A N/A]]);
        }
    }
    return @{ $self->chi->get($key) };
}

sub recursing_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my $key  = "recursing_percentage_for_testrun " . $tr->id;

    unless ($self->chi->is_valid($key)) {
        my $all = $tr->tests->count;
        if ($all > 0) {
            my $ds = $tr->search_related('tests', {})->search_related(
                'results',
                { message  => 'NAMESERVER:RECURSIVE' },
                { group_by => ['test_id'] }
            )->count;

            $self->chi->set($key, [100 * ($ds / $all), $ds]);
        } else {
            $self->chi->set($key, [qw[N/A N/A]]);
        }
    }
    return @{ $self->chi->get($key) };
}

sub adsp_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my $key  = "adsp_percentage_for_testrun " . $tr->id;

    unless ($self->chi->is_valid($key)) {
        my $all = $tr->tests->count;
        if ($all > 0) {
            my $adsp = $self->dbx('Mailserver')->search(
                {
                    run_id => $tr->id,
                    adsp   => { '!=', undef }
                },
                { group_by => ['domain_id'] }
            )->count;

            $self->chi->set($key, [100 * ($adsp / $all), $adsp]);
        } else {
            $self->chi->set($key, [qw[N/A N/A]]);
        }
    }
    return @{ $self->chi->get($key) };
}

sub spf_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my $key  = 'spf_percentage_for_testrun ' . $tr->id;

    unless ($self->chi->is_valid($key)) {
        my $all = $tr->tests->count;
        if ($all > 0) {
            my $adsp = $self->dbx('Mailserver')->search(
                {
                    run_id => $tr->id,
                    '-or'  => {
                        spf_spf => { '!=', undef },
                        spf_txt => { '!=', undef }
                    }
                },
                { group_by => ['domain_id'] }
            )->count;

            $self->chi->set($key, [100 * ($adsp / $all), $adsp]);
        } else {
            $self->chi->set($key, [qw[N/A N/A]]);
        }
    }
    return @{ $self->chi->get($key) };
}

sub starttls_percentage_for_testrun {
    my $self = shift;
    my $tr   = shift;
    my $key  = 'starttls_percentage_for_testrun ' . $tr->id;

    unless ($self->chi->is_valid($key)) {
        my $all = $tr->tests->count;
        if ($all > 0) {
            my $starttls = $self->dbx('Mailserver')->search(
                { run_id   => $tr->id, starttls => 1 },
                { group_by => ['domain_id'] }
            )->count;

            $self->chi->set($key, [100 * ($starttls / $all), $starttls]);
        } else {
            $self->chi->set($key, [qw[N/A N/A]]);
        }
    }
    return @{ $self->chi->get($key) };
}

sub nameserver_count {
    my $self = shift;
    my ($tr, $ipv6) = @_;
    my $key = 'nameserver_count ' . $tr->id . ' ' . $ipv6;

    unless ($self->chi->is_valid($key)) {
        my $divider = $ipv6 ? '%:%' : '%.%';

        $self->chi->set(
            $key,
            $tr->search_related('tests', {})->search_related(
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
              )->count
        );
    }
    return $self->chi->get($key);
}

sub mailservers_in_sweden {
    my $self = shift;
    my ($tr, $ipv6) = @_;
    my $key = 'mailservers_in_sweden ' . $tr->id . ' ' . $ipv6;

    unless ($self->chi->is_valid($key)) {
        my $ms =
          $tr->search_related('servers', { kind => 'SMTP', ipv6 => $ipv6 })
          ->count;
        my $se =
          $tr->search_related('servers',
            { kind => 'SMTP', ipv6 => $ipv6, code => 'SE' })->count;

        if ($ms > 0) {
            $self->chi->set($key, [100 * ($se / $ms), $se]);
        } else {
            $self->chi->set($key, ['N/A', 'N/A']);
        }
    }
    return @{ $self->chi->get($key) };
}

sub message_bands {
    my $self = shift;
    my ($tr, $level) = @_;
    my $cache_key = 'message_bands ' . $tr->id . ' ' . $level;

    unless ($self->chi->is_valid($cache_key)) {
        my $key = lc('count_' . $level);

        my $r0 = $tr->search_related('tests', { $key => 0 })->count;
        my $r1 = $tr->search_related('tests', { $key => 1 })->count;
        my $r2 = $tr->search_related('tests', { $key => 2 })->count;
        my $rn = $tr->search_related('tests', { $key => { '>=', 3 } })->count;

        $self->chi->set($cache_key, [$r0, $r1, $r2, $rn]);
    }

    return @{ $self->chi->get($cache_key) };
}

sub lookup_desc {
    my $self = shift;
    my ($message) = @_;

    return $locale->{messages}{$message}{descr};
}

sub pageanalyzer_summary {
    my $self = shift;
    my @tr   = @_;
    my %res;

    foreach my $tr (@tr) {
        my $res = $self->dbproxy('zonestat')->pageanalyze_summary(
            group    => 'true',
            startkey => ['' . $tr, 'A'],
            endkey   => ['' . $tr, 'z']
        )->{rows};

        $res{$tr} = { map { $_->{key}[1] => $_->{value} } @{$res} };
    }
    return %res;
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
