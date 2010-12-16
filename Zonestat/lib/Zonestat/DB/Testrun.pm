package Zonestat::DB::Testrun;

use strict;
use warnings;

use base 'Zonestat::DB::Common';

use POSIX qw[strftime];

sub fetch {
    my $self = shift;

    my $doc = $self->db('zonestat-testrun')->newDoc($self->{id});
    $doc->retrieve;

    $self->{doc} = $doc;

    return $self;
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
