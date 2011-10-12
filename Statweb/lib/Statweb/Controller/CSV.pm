package Statweb::Controller::CSV;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Statweb::Controller::CSV - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub auto : Private {
    my ($self, $c) = @_;
    my $db = $c->model('DB');

    $c->stash(
        {
            trs => [
                sort   { $b->test_count <=> $a->test_count }
                  grep { $_ }
                  map  { $db->testrun($_) }
                  keys %{ $c->session->{testruns} }
            ],
            current_view => 'CSV',
        }
    );

    return 1;
}

sub webserver_software_http : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'software_http_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/showstats/webpages_software');
    $c->stash->{data} = $c->stash->{data}{software}{http};
}

sub webserver_software_https : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'software_https_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/showstats/webpages_software');
    $c->stash->{data} = $c->stash->{data}{software}{https};
}

sub webserver_response_http : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'response_http_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/showstats/webpages_response');
    $c->stash->{data} = $c->stash->{data}{response}{http};
}

sub webserver_response_https : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'response_https_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/showstats/webpages_response');
    $c->stash->{data} = $c->stash->{data}{response}{https};
}

sub webserver_content_http : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'content_http_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/showstats/webpages_content');
    $c->stash->{data} = $c->stash->{data}{content}{http};
}

sub webserver_content_https : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'content_https_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/showstats/webpages_content');
    $c->stash->{data} = $c->stash->{data}{content}{https};
}

sub webserver_charset_http : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'charset_http_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/showstats/webpages_charset');
    $c->stash->{data} = $c->stash->{data}{charset}{http};
}

sub webserver_charset_https : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'charset_https_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/showstats/webpages_charset');
    $c->stash->{data} = $c->stash->{data}{charset}{https};
}

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
