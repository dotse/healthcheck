package Statweb::Controller::User;

use strict;
use warnings;
use parent 'Catalyst::Controller';

sub login : Local : Arg(0) {
    my ($self, $c) = @_;

    my $username = $c->request->params->{username};
    my $password = $c->request->params->{password};

    if (defined($username) and defined($password)) {
        if (my $user = $c->model('DB')->zs->user->login($username, $password)) {
            $c->session->{user_id} = $user->id;
            $c->res->redirect($c->uri_for_action('/index'));
            return 1;
        } else {
            $c->stash({ message => 'Username and password do not match.' });
        }
    }

    $c->stash({ template => 'login.tt' });
}

sub logout : Local : Arg(0) {
    my ($self, $c) = @_;

    delete $c->session->{user_id};
    $c->res->redirect($c->uri_for('login'));
}

=head1 NAME

Statweb::Controller::User - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 login

Login action. Marks the session with a user id if given a correct
username/password combination.

=head2 logout

Removes user information from the session.

=head1 AUTHOR

Calle Dybedahl

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
