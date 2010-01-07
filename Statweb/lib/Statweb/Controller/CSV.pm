package Statweb::Controller::CSV;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use Data::Dumper;
use Text::CSV_XS;

=head1 NAME

Statweb::Controller::CSV - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index : Path : Args(0) {
    my ($self, $c) = @_;

    $c->response->body('Matched Statweb::Controller::CSV in CSV.');
}

sub webserver_software_http : Local : Args(0) {
    my ($self, $c) = @_;
    my $csv      = Text::CSV_XS->new;
    my $res      = '';
    my $filename = $c->stash->{pagetitle};

    $filename =~ s/\W/_/;
    $c->forward('/testruns/webpages_software');

    foreach my $r (@{ $c->stash->{data}{software}{http} }) {
        $csv->combine(@$r);
        $res .= $csv->string;
        $res .= "\n";
    }

    $c->res->content_type('text/comma-separated-values');
    $c->res->header('Content-Disposition',
        'attachment; filename="' . $filename . '.csv"');
    $c->res->body($res);
}

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
