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

sub auto : Private {
    my ($self, $c) = @_;
    my $db = $c->model('DB::Testrun');

    $c->stash(
        {
            trs => [
                sort   { $b->tests->count <=> $a->tests->count }
                  grep { $_ }
                  map  { $db->find($_) }
                  keys %{ $c->session->{testruns} }
            ]
        }
    );

    return 1;
}

sub webserver_software_http : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'software_http_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/testruns/webpages_software');
    $c->stash->{csv_data} = $c->stash->{data}{software}{http};
    $c->detach('send_csv');
}

sub webserver_software_https : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'software_https_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/testruns/webpages_software');
    $c->stash->{csv_data} = $c->stash->{data}{software}{https};
    $c->detach('send_csv');
}

sub webserver_response_http : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'response_http_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/testruns/webpages_response');
    $c->stash->{csv_data} = $c->stash->{data}{response}{http};
    $c->detach('send_csv');
}

sub webserver_response_https : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'response_https_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/testruns/webpages_response');
    $c->stash->{csv_data} = $c->stash->{data}{response}{https};
    $c->detach('send_csv');
}

sub webserver_content_http : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'content_http_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/testruns/webpages_content');
    $c->stash->{csv_data} = $c->stash->{data}{content}{http};
    $c->detach('send_csv');
}

sub webserver_content_https : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'content_https_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/testruns/webpages_content');
    $c->stash->{csv_data} = $c->stash->{data}{content}{https};
    $c->detach('send_csv');
}

sub webserver_charset_http : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'charset_http_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/testruns/webpages_charset');
    $c->stash->{csv_data} = $c->stash->{data}{charset}{http};
    $c->detach('send_csv');
}

sub webserver_charset_https : Local : Args(0) {
    my ($self, $c) = @_;
    $c->stash->{filename} = 'charset_https_' . join '-',
      keys %{ $c->session->{testruns} };

    $c->forward('/testruns/webpages_charset');
    $c->stash->{csv_data} = $c->stash->{data}{charset}{https};
    $c->detach('send_csv');
}

sub send_csv : Private {
    my ($self, $c) = @_;
    my $csv      = Text::CSV_XS->new;
    my $res      = '';
    my $filename = $c->stash->{filename};

    foreach my $r (@{ $c->stash->{csv_data} }) {
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
