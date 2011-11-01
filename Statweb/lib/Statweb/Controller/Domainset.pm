package Statweb::Controller::Domainset;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Zonestat;

sub index : Chained('/') : CaptureArgs(1) : PathPart('domainset') {
    my ($self, $c, $id) = @_;
    my $ds = $c->model('DB')->domainset($id);

    $c->stash(
        {
            dset     => $ds,
            template => 'domainset/index.tt'
        }
    );
}

sub first : Chained('index') : Args(0) : PathPart('') {
    my ($self, $c) = @_;

    $c->detach('later', [1,'n']);
}

sub later : Chained('index') : Args(1) : PathPart('') {
    my ($self, $c, $page) = @_;

    ($c->stash->{rows}, $c->stash->{nextkey}) =
      $c->stash->{dset}->page($page);
    $c->stash->{prevkey} = $c->stash->{dset}->prevkey($page);
}

sub delete : Chained('index') : Args(1) : PathPart('delete') {
    my ($self, $c, $domain_id) = @_;

    $c->stash->{dset}->remove($domain_id);

    $c->res->redirect(
        $c->uri_for_action('/domainset/first', [$c->stash->{dset}->name]));
}

sub add : Chained('index') : Args(0) : PathPart('add') {
    my ($self, $c) = @_;
    my $domainname = $c->req->params->{domainname};

    $c->stash->{dset}->add($domainname);

    $c->res->redirect(
        $c->uri_for_action('/domainset/first', [$c->stash->{dset}->name]));
}

sub create :Local {
    my ($self, $c) = @_;

    my $up = $c->req->upload('userfile');
    my $fh = $up->fh;
    my @domains = <$fh>;
    chomp(@domains);

    my $name = $c->req->params->{name};
    die unless $name;
    my $dset = $c->model('DB')->domainset($name);
    $dset->clear;
    $dset->add(@domains);

    $c->res->redirect(
        $c->uri_for_action('/domainset/first', [$name]));
}

=head1 NAME

Statweb::Controller::Domainset - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 ACTIONS

=item index

Start of the delegation chain for all pages working with one particular
domainset. Picks that domainset out of the URL and puts the right object in
the stash.

=item first

Catches display of domainset without a page number. Adds the number 1 and sends the request on to C<later>.

=item later

Displays one page of domain names in a set.

=item delete

Remove a domain name from the set.

=item add

Add a domain name to the set.

=item create

Create a new domainset, with domain names taken from an uploaded file with one
name per line.

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
