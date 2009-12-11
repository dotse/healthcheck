package Statweb::Controller::Testruns;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use Data::Dumper;

=head1 NAME

Statweb::Controller::Testruns - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my $db = $c->model('DB::Testrun');
    my @trs = grep {$_} map {$db->find($_)} keys %{$c->session->{testruns}};
    my $name;
    my %data;
    my $p = $c->{zs}->present;
    
    if (@trs == 1) {
        $name = $trs[0]->name;
    } else {
        $name = scalar(@trs) . ' testruns';
    }
    
    $data{names} = [ map {$_->domainset->name . ' ' . $_->name} @trs];

    $data{ipv6domains} = [
        map {sprintf "%0.2f%% (%d)", $p->ipv6_percentage_for_testrun($_)} @trs
    ];

    $data{ipv4as} = [
        map {sprintf "%0.2f%% (%d)", $p->multihome_percentage_for_testrun($_,0)} @trs
    ];

    $data{ipv6as} = [
        map {sprintf "%0.2f%% (%d)", $p->multihome_percentage_for_testrun($_,1)} @trs
    ];

    $data{dnssec} = [
        map {sprintf "%0.2f%% (%d)", $p->dnssec_percentage_for_testrun($_)} @trs
    ];

    $data{recursive} = [
        map {sprintf "%0.2f%% (%d)", $p->recursing_percentage_for_testrun($_)} @trs
    ];

    $data{adsp} = [
        map {sprintf "%0.2f%% (%d)", $p->adsp_percentage_for_testrun($_)} @trs
    ];

    $data{spf} = [
        map {sprintf "%0.2f%% (%d)", $p->spf_percentage_for_testrun($_)} @trs
    ];

    $data{starttls} = [
        map {sprintf "%0.2f%% (%d)", $p->starttls_percentage_for_testrun($_)} @trs
    ];

    $data{mailv4} = [
        map {sprintf "%0.2f%% (%d)", $p->mailservers_in_sweden($_,0)} @trs
    ];

    $data{mailv6} = [
        map {sprintf "%0.2f%% (%d)", $p->mailservers_in_sweden($_,1)} @trs
    ];

    $data{tested} = [
        map {$_->tests->count} @trs
    ];

    $data{distinctv4} = [
        map {$p->nameserver_count($_,0)} @trs
    ];

    $data{distinctv6} = [
        map {$p->nameserver_count($_,1)} @trs
    ];

    $data{http} = [
        map {$_->search_related('webservers',{https => 0})->count} @trs
    ];

    $data{https} = [
        map {$_->search_related('webservers',{https => 1})->count} @trs
    ];

    $c->stash({
       template => 'testruns/index.tt', 
       pagetitle => $name,
       data => \%data,
    });
}

sub webpages :Local :Args(0) {
    my ( $self, $c ) = @_;
    my $db = $c->model('DB::Testrun');
    my @trs = grep {$_} map {$db->find($_)} keys %{$c->session->{testruns}};
    my $name;
    my %data;
    my $p = $c->{zs}->present;
    
    if (@trs == 1) {
        $name = $trs[0]->name;
    } else {
        $name = scalar(@trs) . ' testruns';
    }
    
    $data{names} = [ map {$_->domainset->name . ' ' . $_->name} @trs];
    
    $c->stash({
       template => 'testruns/webpages.tt', 
       pagetitle => $name,
       data => \%data,
    });
}

sub dnscheck :Local :Args(0) {
    my ( $self, $c ) = @_;
    my $db = $c->model('DB::Testrun');
    my @trs = grep {$_} map {$db->find($_)} keys %{$c->session->{testruns}};
    my $name;
    my %data;
    my $p = $c->{zs}->present;
    
    if (@trs == 1) {
        $name = $trs[0]->name;
    } else {
        $name = scalar(@trs) . ' testruns';
    }
    
    $data{names} = [ map {$_->domainset->name . ' ' . $_->name} @trs];
    
    $c->stash({
       template => 'testruns/dnscheck.tt', 
       pagetitle => $name,
       data => \%data,
    });
}

sub servers :Local :Args(0) {
    my ( $self, $c ) = @_;
    my $db = $c->model('DB::Testrun');
    my @trs = grep {$_} map {$db->find($_)} keys %{$c->session->{testruns}};
    my $name;
    my %data;
    my $p = $c->{zs}->present;
    
    if (@trs == 1) {
        $name = $trs[0]->name;
    } else {
        $name = scalar(@trs) . ' testruns';
    }
    
    $data{names} = { map {$_->id, $_->domainset->name . ' ' . $_->name} @trs};
    $data{trs} = \@trs;
    
    foreach my $kind (qw[dns smtp http]) {
        foreach my $tr (@trs) {
            my @s = $p->top_foo_servers($kind, $tr, 25);
            $data{$kind}{$tr->id} = [map {
                {
                    reverse => $_->reverse,
                    count => $_->get_column('count'),
                    location => join(', ', grep {$_} ($_->city, $_->country)),
                    geourl => sprintf('http://maps.google.com/maps?q=%02.2f+%02.2f', $_->latitude, $_->longitude)
                }
            } @s];
        }
    }
    
    $c->stash({
       template => 'testruns/servers.tt', 
       pagetitle => $name,
       data => \%data,
    });
}




=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
