package Zonestat::Testrun;

use strict;
use warnings;

use base 'Zonestat::Common';

use POSIX qw[strftime];

sub new {
    my $class  = shift;
    my $parent = shift;
    my $self   = $class->SUPER::new($parent);
    $self->{id} = shift;
    $self->fetch;

    return $self;
}

sub id { return $_[0]->{id} }

sub fetch {
    my $self = shift;

    my $doc = $self->db('zonestat-testrun')->newDoc($self->{id});
    $doc->retrieve;

    $self->{doc} = $doc;

    return $self;
}

sub data {
    my $self = shift;

    return $self->{doc}->data;
}

sub domainset {
    my $self = shift;

    return $self->data->{domainset};
}

sub name {
    my $self   = shift;
    my $dset   = $self->domainset;
    my $time_t = $self->data->{queued_at};

    return $dset . ' ' . strftime('%Y-%m-%d %H:%M', localtime($time_t));
}

1;
