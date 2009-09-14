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
    my @ds    = @_;
    my %res;

    foreach my $ds (@ds) {
        my @rows = $ds->tests->search_related(
            'results',
            { level => $level },
            {
                columns  => [qw(test_id message)],
                distinct => 1
            }
        )->all;
        foreach my $r (@rows) { $res{ $r->message }{ $ds->id }++ }
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
        foreach my $t ($ds->tests->all) {
            if ($t->count_critical > 0) {
                $res{critical}{ $ds->id }++;
            } elsif ($t->count_error > 0) {
                $res{error}{ $ds->id }++;
            } elsif ($t->count_warning > 0) {
                $res{warning}{ $ds->id }++;
            } elsif ($t->count_notice > 0) {
                $res{notice}{ $ds->id }++;
            } elsif ($t->count_info > 0) {
                $res{info}{ $ds->id }++;
            } else {
                $res{clear}{ $ds->id }++;
            }
        }
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
            select =>
              [qw[ip latitude longitude country code city], { count => '*' }],
            as       => [qw[ip latitude longitude country code city], 'count'],
            group_by => [qw[ip latitude longitude country code city]],
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
