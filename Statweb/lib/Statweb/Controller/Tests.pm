package Statweb::Controller::Tests;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use List::Util qw[max];

sub index : Path : Args(2) {
    my ($self, $c, $trid, $domain) = @_;
    my $test = $c->model('DB')->db('zonestat')->newDoc($trid . '-' . $domain);
    $test->retrieve;
    my @ordered = sort {$a->{timestamp} <=> $b->{timestamp}} @{$test->data->{dnscheck}};
    my $arg_count = max map {scalar(@{$_->{args}})} @ordered;

    $c->stash(
        {
            template => 'tests/index.tt',
            domain => $domain,
            test     => \@ordered,
            arg_count => $arg_count,
        }
    );
}

=head1 NAME

Statweb::Controller::Tests - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 index

Show the DNSCheck results for a certain domain in a certain testrun.

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
