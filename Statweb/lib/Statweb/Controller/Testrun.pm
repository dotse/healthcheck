package Statweb::Controller::Testrun;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Statweb::Controller::Testrun - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Chained('/') :CaptureArgs(1) :PathPart('testrun') {
    my ( $self, $c, $run_id ) = @_;

    $c->stash(run =>  $c->model('DB::Testrun')->find($run_id));
}

sub show :Chained('index') :Args(0) :PathPart('') {
    my ($self, $c) = @_;
    
    $c->stash(template => 'testrun/show.tt');
}

sub domain :Chained('index') :CaptureArgs(1) :PathPart('') {
    my ($self, $c, $domain_id) = @_;
    
    my $domain = $c->model('DB::Domains')->find($domain_id) or die "No domain ($domain_id)!";
    $c->stash(domain => $domain);
}

sub details :Chained('domain') :Args(0) :PathPart('') {
    my ($self, $c) = @_;
    
    my $web = $c->stash->{run}->search_related('webservers', {domain_id => $c->stash->{domain}->id});
    $c->stash(web => [$web->all]);
    $c->stash(template => 'testrun/details.tt');
}


=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

