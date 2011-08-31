package Statweb::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

Statweb::Controller::Root - Root Controller for Statweb

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ($self, $c) = @_;

    $c->stash({ dset => [$c->model('DB')->dset->all_sets] });
}

sub default : Path {
    my ($self, $c) = @_;
    $c->response->body('Page not found');
    $c->response->status(404);
}

sub begin : Private {
    my ($self, $c) = @_;

    unless ($c->res->content_type) {
        $c->res->content_type('text/html;charset=iso-8859-1');
    }

}

sub auto : Private {
    my ($self, $c) = @_;

    if ($c->controller eq $c->controller('User')) {
        return 1;
    }

    unless ($c->session->{user_id}) {
        $c->res->redirect($c->uri_for('/user/login'));
        return 0;
    }

    $c->forward('left_bar');
    $c->{zs}   = Zonestat->new;
    $c->{user} = $c->{zs}->user($c->session->{user_id});
}

sub left_bar : Private {
    my ($self, $c) = @_;

    my @runs =
      grep { $_ }
      map  { $c->model('DB')->testrun($_) }
      keys %{ $c->session->{testruns} };
    my %sets = map { $_->{set} => 1 } @runs;

    $c->stash(
        {
            selected_run_count => scalar(@runs),
            selected_set_count => scalar(keys %sets),
            queue_length       => $c->model('DB')->queue->length,
        }
    );
}

sub toggletestrun : Global : Arg(1) {
    my ($self, $c, $trid) = @_;

    my %tr = %{ $c->session->{testruns} };

    if ($tr{$trid}) {
        delete $tr{$trid};
    } else {
        $tr{$trid} = 1;
    }

    $c->session->{testruns} = \%tr;
    $c->res->redirect('/');
}

sub clearselection : Global : Arg(0) {
    my ($self, $c) = @_;

    $c->session->{testruns} = {};

    $c->res->redirect('/');
}

sub enqueue : Global : Arg(1) {
    my ($self, $c, $dsid) = @_;

    my $ds = $c->model('DB::Domainset')->find($dsid);
    $c->{zs}->gather->enqueue_domainset($ds);
    $c->res->redirect('/');
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
}

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
