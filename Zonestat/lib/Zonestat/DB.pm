package Zonestat::DB;

use strict;
use warnings;

use base 'Zonestat::Common';

sub new {
    my $class  = shift;
    my $parent = shift;
    my $self   = $class->SUPER::new($parent);
    $self->{name} = shift;

    $self->initialize;

    return $self;
}

sub name { return $_[0]->{name} }

sub db {
    my $self = shift;
    my $name = shift || $self->name;

    return $self->SUPER::db($name);
}

sub initialize {
    my $self = shift;
    my $ddocs = $self->db->listDesignDocs;
    
    foreach my $ddoc (@{$ddocs}) {
        foreach my $view ($ddoc->listViews) {
            print "$view\n"
        }
    }
}

1;