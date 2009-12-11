package Statweb::Controller::Tests;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Statweb::Controller::Tests - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(1) {
    my ($self, $c, $id) = @_;
    my $test = $c->model('DB::Tests')->find($id);

    $c->stash(
        {
            template => 'tests/index.tt',
            test     => $test,
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
