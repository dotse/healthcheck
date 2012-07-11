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

sub index : Path : Args(0) {
    my ($self, $c) = @_;

    $c->stash->{dset} = [$c->model('DB')->dset->all_sets];
    $c->stash->{maxchildren} = $c->model('DB')->zs->cget(qw[daemon maxchild]);
}

sub default : Path {
    my ($self, $c) = @_;
    $c->response->body('Page not found');
    $c->response->status(404);
}

sub begin : Private {
    my ($self, $c) = @_;

    unless ($c->res->content_type) {
        $c->res->content_type('text/html;charset=UTF-8');
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
    $c->{zs}   = Zonestat->new($ENV{ZONESTAT_CONFIG_FILE});
    $c->{user} = $c->{zs}->user($c->session->{user_id});
}

sub left_bar : Private {
    my ($self, $c) = @_;

    my @runs =
      grep { $_ }
      map  { $c->model('DB')->testrun($_) }
      keys %{ $c->session->{testruns} };
    my %sets = map { $_->domainset => 1 } @runs;

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
    $c->res->redirect($c->uri_for_action('/index'));
}

sub clearselection : Global : Arg(0) {
    my ($self, $c) = @_;

    $c->session->{testruns} = {};

    $c->res->redirect($c->uri_for_action('/index'));
}

sub enqueue : Global : Arg(1) {
    my ($self, $c, $dsid) = @_;

    my $ds = $c->model('DB')->domainset($dsid);
    $ds->enqueue();
    $c->res->redirect($c->uri_for_action('/index'));
}

sub end : ActionClass('RenderView') {
}

=head1 NAME

Statweb::Controller::Root - Root Controller for Statweb

=head1 DESCRIPTION

Controller for the first logged-in page of Statweb.

=head1 ACTIONS

=over

=item index

Main index page, showing all domainsets and all testruns.

=item default

404 handler.

=item begin

Set the default content-type to C<text/html> and the character encoding to UTF-8.

=item auto

Limit view of pages to logged-in users.

=item left_bar

Put data in the stash that's needed to display the common left bar on all pages.

=item toggletestrun

Include or remove a testrun from being shown on the statistics pages.

=item clearselection

Remove all testruns from the list of included runs.

=item enqueue

Put all the domain names in a domainset on the gathering queue.

=item end

Default handler to hand over to the TT view.

=back

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
