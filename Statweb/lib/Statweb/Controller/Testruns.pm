package Statweb::Controller::Testruns;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use Data::Dumper;
use Time::HiRes qw[time];

=head1 NAME

Statweb::Controller::Testruns - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ($self, $c) = @_;

    my $db = $c->model('DB::Testrun');
    my @trs =
      grep { $_ } map { $db->find($_) } keys %{ $c->session->{testruns} };
    my $name;
    my %data;
    my $p = $c->{zs}->present;

    if (@trs == 1) {
        $name = $trs[0]->name;
    } else {
        $name = scalar(@trs) . ' testruns';
    }

    $data{names} = [map { $_->domainset->name . ' ' . $_->name } @trs];

    $data{ipv6domains} =
      [map { sprintf "%0.2f%% (%d)", $p->ipv6_percentage_for_testrun($_) }
          @trs];

    $data{ipv4as} = [
        map {
            sprintf "%0.2f%% (%d)",
              $p->multihome_percentage_for_testrun($_, 0)
          } @trs
    ];

    $data{ipv6as} = [
        map {
            sprintf "%0.2f%% (%d)",
              $p->multihome_percentage_for_testrun($_, 1)
          } @trs
    ];

    $data{dnssec} =
      [map { sprintf "%0.2f%% (%d)", $p->dnssec_percentage_for_testrun($_) }
          @trs];

    $data{recursive} = [
        map { sprintf "%0.2f%% (%d)", $p->recursing_percentage_for_testrun($_) }
          @trs
    ];

    $data{adsp} =
      [map { sprintf "%0.2f%% (%d)", $p->adsp_percentage_for_testrun($_) }
          @trs];

    $data{spf} =
      [map { sprintf "%0.2f%% (%d)", $p->spf_percentage_for_testrun($_) } @trs];

    $data{starttls} =
      [map { sprintf "%0.2f%% (%d)", $p->starttls_percentage_for_testrun($_) }
          @trs];

    $data{mailv4} =
      [map { sprintf "%0.2f%% (%d)", $p->mailservers_in_sweden($_, 0) } @trs];

    $data{mailv6} =
      [map { sprintf "%0.2f%% (%d)", $p->mailservers_in_sweden($_, 1) } @trs];

    $data{tested} = [map { $_->tests->count } @trs];

    $data{distinctv4} = [map { $p->nameserver_count($_, 0) } @trs];

    $data{distinctv6} = [map { $p->nameserver_count($_, 1) } @trs];

    $data{http} =
      [map { $_->search_related('webservers', { https => 0 })->count } @trs];

    $data{https} =
      [map { $_->search_related('webservers', { https => 1 })->count } @trs];

    $c->stash(
        {
            template  => 'testruns/index.tt',
            pagetitle => $name,
            data      => \%data,
        }
    );
}

sub webpages : Local : Args(0) {
    my ($self, $c) = @_;
    my $db = $c->model('DB::Testrun');
    my @trs =
      grep { $_ } map { $db->find($_) } keys %{ $c->session->{testruns} };
    my $name;
    my %data;
    my $p = $c->{zs}->present;

    if (@trs == 1) {
        $name = $trs[0]->name;
    } else {
        $name = scalar(@trs) . ' testruns';
    }

    $data{names} = [map { $_->domainset->name . ' ' . $_->name } @trs];

    $c->stash(
        {
            template  => 'testruns/webpages.tt',
            pagetitle => $name,
            data      => \%data,
        }
    );
}

sub dnscheck : Local : Args(0) {
    my ($self, $c) = @_;
    my $db = $c->model('DB::Testrun');

  # Sort in falling order of number of domains in the set (there is one test per
  # domain).
    my @trs =
      sort { $b->tests->count <=> $a->tests->count }
      grep { $_ } map { $db->find($_) } keys %{ $c->session->{testruns} };
    my %sizes = map {$_->id, $_->tests->count} @trs;
    my $name;
    my %data;
    my $p        = $c->{zs}->present;
    my %errors   = $p->number_of_domains_with_message('ERROR', @trs);
    my %warnings = $p->number_of_domains_with_message('WARNING', @trs);
    my @eorder =
      sort { $errors{$b}{ $trs[0]->id } <=> $errors{$a}{ $trs[0]->id } }
      keys %errors;
    my @worder =
      sort { $warnings{$b}{ $trs[0]->id } <=> $warnings{$a}{ $trs[0]->id } }
      keys %warnings;
    my %descriptions;

    foreach my $m (@eorder, @worder) {
        $descriptions{$m} = $p->lookup_desc($m);
    }

    # "Message band" tables.
    my %band;
    foreach my $level (qw[CRITICAL ERROR WARNING]) {
        foreach my $tr (@trs) {
            $band{$level}{ $tr->id } = [$p->message_bands($tr, $level)];
        }
    }

    # "Max severity" table
    my %severity = $p->tests_with_max_severity(@trs);

    if (@trs == 1) {
        $name = $trs[0]->name;
    } else {
        $name = scalar(@trs) . ' testruns';
    }

    $data{names} = [map { $_->domainset->name . ' ' . $_->name } @trs];

    $c->stash(
        {
            template     => 'testruns/dnscheck.tt',
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
            sizes => \%sizes,
        }
    );
}

sub servers : Local : Args(0) {
    my ($self, $c) = @_;
    my $db = $c->model('DB::Testrun');
    my @trs =
      sort { $b->tests->count <=> $a->tests->count }
      grep { $_ } map { $db->find($_) } keys %{ $c->session->{testruns} };
    my $name;
    my %data;
    my $p = $c->{zs}->present;

    if (@trs == 1) {
        $name = $trs[0]->name;
    } else {
        $name = scalar(@trs) . ' testruns';
    }

    $data{names} =
      { map { $_->id, $_->domainset->name . ' ' . $_->name } @trs };
    $data{trs} = \@trs;

    foreach my $kind (qw[dns smtp http]) {
        foreach my $tr (@trs) {
            my @s = $p->top_foo_servers($kind, $tr, 25);
            $data{$kind}{ $tr->id } = [
                map {
                    {
                        reverse => $_->reverse,
                          count => $_->get_column('count'),
                          location =>
                          join(', ', grep { $_ } ($_->city, $_->country)),
                          geourl =>
                          ($_->latitude and $_->longitude)?sprintf('http://maps.google.com/maps?q=%02.2f+%02.2f',
                            $_->latitude, $_->longitude):''
                    }
                  } @s
            ];
        }
    }

    my %ns_per_asn_v4 = $p->nameservers_per_asn(0, @trs);
    my %ns_per_asn_v6 = $p->nameservers_per_asn(1, @trs);
    my %asnames;
    my $asn = $c->model('DB::Asdata');

    foreach my $as (keys %ns_per_asn_v4, keys %ns_per_asn_v6) {
        my $r = $asn->search({ asn => $as });
        if (defined($r) and defined($r->first)) {
            $asnames{$as} = $r->first->asname;
        } else {
            $asnames{$as} = 'No name';
        }
    }

    my @asv4order = sort {
        $ns_per_asn_v4{$b}{ $trs[0]->id } <=> $ns_per_asn_v4{$a}{ $trs[0]->id }
    } keys %ns_per_asn_v4;
    splice @asv4order, 20 if @asv4order > 20;
    my @asv6order = sort {
        $ns_per_asn_v6{$b}{ $trs[0]->id } <=> $ns_per_asn_v6{$a}{ $trs[0]->id }
    } keys %ns_per_asn_v6;
    splice @asv6order, 20 if @asv6order > 20;

    $c->stash(
        {
            template      => 'testruns/servers.tt',
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
    my ($self, $c, $level, $trid) = @_;
    my $tr = $c->model('DB::Testrun')->find($trid);
    my @tests =
      $tr->search_related('tests', { 'count_' . lc($level) => { '>', 0 } })
      ->all;

    $c->stash(
        {
            template => 'testruns/view_by_level.tt',
            tr       => $tr,
            level    => $level,
            tests    => \@tests,
        }
    );
}

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
