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
    my $self = shift;
    my ( $name, $pwd ) = @_;

    return unless ( $name and $pwd );

    my $user = $self->by_id( $name );
    return unless $user;

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

sub by_id {
    my $self   = shift;
    my ( $id ) = @_;
    my $db     = $self->db( 'zonestat-user' );

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

    return $self->{user}{username};
}

sub id {
    my $self = shift;

    return $self->{user}{name};
}

1;
