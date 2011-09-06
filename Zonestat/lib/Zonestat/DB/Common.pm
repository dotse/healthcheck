package Zonestat::DB::Common;

use strict;
use utf8;
use warnings;

use base 'Zonestat::Common';

sub new {
    my $class  = shift;
    my $parent = shift;
    my $self   = $class->SUPER::new( $parent );
    my $id     = shift;

    if ( defined( $id ) ) {
        $self->{id} = $id;
        $self->fetch;
    }

    return $self;
}

sub id {
    my $self = shift;

    return $self->{id};
}

sub data {
    my $self = shift;

    return $self->{doc}->data;
}

1;
