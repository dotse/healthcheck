package Statweb::Controller::Domainset;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Statweb::Controller::Domainset - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Chained('/') : CaptureArgs(1) : PathPart('domainset') {
    my ($self, $c, $id) = @_;
    my $ds = $c->model('DB::Domainset')->find($id);

    $c->stash(
        {
            dset     => $ds,
            template => 'domainset/index.tt'
        }
    );
}

sub first : Chained('index') : Args(0) : PathPart('') {
    my ($self, $c) = @_;

    $c->stash->{rows} =
      $c->stash->{dset}
      ->search_related('glue', undef, { page => 1, rows => 25 });
    $c->stash->{page} = $c->stash->{rows}->pager;
}

sub later : Chained('index') : Args(1) : PathPart('') {
    my ($self, $c, $page) = @_;

    $c->stash->{rows} =
      $c->stash->{dset}
      ->search_related('glue', undef, { page => $page, rows => 25 });
    $c->stash->{page} = $c->stash->{rows}->pager;
}

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
