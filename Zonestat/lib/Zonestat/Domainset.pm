package Zonestat::Domainset;

use strict;
use warnings;

use base 'Zonestat::Common';

use Digest::SHA1 qw[sha1_hex];
use Try::Tiny;

sub new {
    my $class = shift;
    my $parent = shift;
    my $self = $class->SUPER::new($parent);
    $self->{name} = shift;
    
    return $self;
}

sub name { return $_[0]->{name}}

sub db {
    my $self = shift;
    
    return $self->SUPER::db('zonestat-dset');
}

sub id {
    my $self = shift;
    my $domain = shift;
    
    return sha1_hex($self->name . $domain);
}

sub add {
    my $self = shift;
    my @domains = @_;
    my $name = $self->name;
    
    $self->db->bulkStore([
        map {$self->db->newDoc($self->id($_), undef, {domain => $_, set => $name})} @domains
        ]);
    
    return $self;
}

sub remove {
    my $self = shift;
    my $domain = shift;
    
    my $doc = $self->db->newDoc($self->id($domain), undef);
    try {
        $doc->retrieve;
        $doc->delete;
    };
    
    return $self;
}

sub all {
    my $self = shift;
    my $ddoc = $self->db->newDesignDoc('_design/util');

    $ddoc->retrieve;
    return map {$_->{value}} @{$ddoc->queryView('set', key => $self->name)->{rows}};
}

sub clear {
    my $self = shift;
    
    foreach my $domain ($self->all) {
        my $doc = $self->db->newDoc($self->id($domain));
        $doc->retrieve;
        $doc->delete;
    }
    
    return $self;
}

1;