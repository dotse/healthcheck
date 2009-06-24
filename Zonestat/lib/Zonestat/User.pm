package Zonestat::User;

use 5.008008;
use strict;
use warnings;

use base 'Zonestat::Common';
use Digest::SHA1 'sha1_hex';

our $VERSION = '0.01';

sub login {
    my $self = shift;
    my ($name, $pwd) = @_;
    my $table = $self->dbx('User');

    return unless ($name and $pwd);
    $self->{user} =
      $table->search({ username => $name, password => sha1_hex($pwd) })->first;

    if ($self->{user}) {
        return $self;
    } else {
        return;
    }
}

sub by_id {
    my $self  = shift;
    my ($id)  = @_;
    my $table = $self->dbx('User');

    $self->{user} = $table->find($id);
    return $self;
}

sub name {
    my $self = shift;

    return $self->{user}->displayname;
}

sub email {
    my $self = shift;

    return $self->{user}->email;
}

sub username {
    my $self = shift;

    return $self->{user}->username;
}

sub id {
    my $self = shift;

    return $self->{user}->id;
}

1;
