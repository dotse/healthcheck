package Zonestat::DB::User;

use 5.008008;
use strict;
use utf8;
use warnings;

use base 'Zonestat::DB::Common';
use Digest::SHA1 'sha1_hex';
use Try::Tiny;
use Carp;

our $VERSION = '0.02';

sub login {
    my ( $self, $name, $pwd ) = @_;

    return unless ( $name and $pwd );

    my $user = $self->by_id( $name );
    return unless $user && $user->{user} && $user->{user}{password};

    if ( sha1_hex( $user->{user}{salt} . $pwd ) eq $user->{user}{password} ) {
        return $user;
    }
    else {
        return;
    }
}

sub create {
    my ( $self, $name, $password, $displayname, $email ) = @_;
    my $db = $self->db( 'zonestat-user' );

    croak "User $name already exists" if $db->docExists( $name );

    my $doc = $db->newDoc( $name );
    $doc->data->{salt}        = sha1_hex( rand() );
    $doc->data->{password}    = sha1_hex( $doc->data->{salt} . $password );
    $doc->data->{email}       = $email;
    $doc->data->{displayname} = $displayname;
    $doc->data->{name}        = $name;
    $doc->create;

    $self->{user} = $doc->data;

    return $self;
}

sub set_password {
    my ( $self, $user, $new ) = @_;

    my $doc = $self->db('zonestat-user')->newDoc( $user );
    $doc->retrieve;
    $doc->data->{password} = sha1_hex( $doc->data->{salt} . $new );
    $doc->update;

    return;
}

sub by_id {
    my ( $self, $id ) = @_;
    my $db = $self->db( 'zonestat-user' );

    my $doc = $db->newDoc( $id );
    try {
        $doc->retrieve;
    }
    catch {
        return;
    };

    $self->{user} = $doc->data;
    return $self;
}

sub name {
    my $self = shift;

    return $self->{user}{displayname};
}

sub email {
    my $self = shift;

    return $self->{user}{email};
}

sub username {
    my $self = shift;

    return $self->{user}{name};
}

sub id {
    my $self = shift;

    return $self->{user}{name};
}

=head1 NAME

Zonestat::DB::User - interface to the user database

=head1 SYNOPSIS

  my $user = Zonestat->new->user->login($username, $password);

=head1 DESCRIPTION

=head2 Class Methods

=over

=item login($username, $password)

If there is a user in the database that matches the given username and
password, an object for that user is returned. If not, C<undef> is returned.

=item by_id($username)

If there is a user by the given name, an object for it is returned. If not,
C<undef> is returned.

=item create($usernamename, $password, $displayname, $email)

Create a new user with the given information. If a user with the same username
already exists, an exception will be thrown.

=item set_password($username, $password)

Set the password of the given user.

=back

=head2 Instance Methods

=over

=item name()

Return the stored real-world name.

=item email()

Return the user's email address.

=item username()

Return the user's username.

=back

1;
