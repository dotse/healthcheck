package Statweb::Controller::Testrun;
use Moose;
use namespace::autoclean;

use POSIX 'strftime';
use List::Util 'max';

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Statweb::Controller::Testrun - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Chained('/') :CaptureArgs(1) :PathPart('testrun') {
    my ( $self, $c, $run_id ) = @_;
    
    my $run = $c->model('DB')->testrun($run_id);

    $c->stash->{run} = $run;
}

sub show :Chained('index') :Args(1) :PathPart('page') {
    my ($self, $c, $startdomain) = @_;

    my @tests = @{$c->stash->{run}->tests($startdomain)};
    my $nextkey = splice(@tests, -1) if scalar(@tests)>=26;
    my @tmp = @{$c->stash->{run}->tests($startdomain, 1)};
    my $prevkey = splice(@tmp,-1) if scalar(@tmp)>=26;

    foreach my $t (@tests) {
        if($t->{start}) {
            $t->{begin} = strftime('%F %T',localtime($t->{start}));
        } else {
            $t->{begin} = 'N/A';
        }
        
        $t->{count_critical} = 0;
        $t->{count_error} = 0;
        $t->{count_warning} = 0;
        foreach my $d (@{$t->{dnscheck}}) {
            if ($d->{level} eq 'CRITICAL') {
                $t->{count_critical}++
            } elsif ($d->{level} eq 'ERROR') {
                $t->{count_error}++
            } elsif ($d->{level} eq 'WARNING') {
                $t->{count_warning} ++
            }
        }
    }

    $c->stash->{tests} = \@tests;
    $c->stash->{nextkey} = $nextkey->{domain} if $nextkey->{testrun} == $c->stash->{run}->id;
    $c->stash->{prevkey} = $prevkey->{domain} if $prevkey->{testrun} == $c->stash->{run}->id;
    $c->stash(template => 'testrun/show.tt');
}

sub first :Chained('index') :Args(0) :PathPart('') {
    my ($self, $c) = @_;
    
    my $url = $c->uri_for_action('/testrun/show', [$c->stash->{run}->id], '0');
    print STDERR 'HERE==> ' . $url . "\n";
    
    $c->res->redirect($url);
}

sub domain :Chained('index') :CaptureArgs(1) :PathPart('detail') {
    my ($self, $c, $domain) = @_;
    
    $c->stash(domain => $domain);
}

sub details :Chained('domain') :Args(0) :PathPart('') {
    my ($self, $c) = @_;
    
    my $doc = $c->model('DB')->db('zonestat')->newDoc($c->stash->{run}->id . '-' . $c->stash->{domain});
    $doc->retrieve;
    
    $c->stash->{arg_count} = (max map {scalar(@{$_->{args}})} @{$doc->data->{dnscheck}}) - 1;
    $c->stash->{doc} = $doc->data;
    $c->stash(template => 'testrun/details.tt');
}


=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

