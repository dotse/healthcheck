package Statweb::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

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

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    # Hello World
    # $c->response->body( $c->welcome_message );
    
    $c->stash({
        now => scalar(localtime),
        dset => [$c->model('DB::Domainset')->all]
    });
}

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

sub begin :Private {
    my ($self, $c) = @_;
    
    unless ($c->res->content_type) {
        $c->res->content_type('text/html;charset=iso-8859-1');
    }
    
}

sub auto :Private {
    my ($self, $c) = @_;
    
    $c->forward('left_bar');
    $c->{zs} = Zonestat->new;
}

sub left_bar :Private {
    my ($self, $c) = @_;
    
    my @runs = grep {$_} map {$c->model('DB::Testrun')->find($_)} keys %{$c->session->{testruns}};
    my %sets = map {$_->set_id => 1} @runs;

    $c->stash({
        selected_run_count => scalar(@runs),
        selected_set_count => scalar(keys %sets),
        queue_length => $c->model('DB::Queue')->count,
    })
}

sub toggletestrun :Global :Arg(1) {
    my ($self, $c, $trid) = @_;

    my %tr = %{$c->session->{testruns}};
    
    if ($tr{$trid}) {
        delete $tr{$trid};
    } else {
        $tr{$trid} = 1;
    }
    
    $c->session->{testruns} = \%tr;
    $c->res->redirect('/');
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
