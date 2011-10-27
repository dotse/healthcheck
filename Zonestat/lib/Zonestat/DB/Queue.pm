package Zonestat::DB::Queue;

use warnings;
use strict;
use utf8;

use base 'Zonestat::DB::Common';

## no critic (Subroutines::ProhibitBuiltinHomonyms)
sub length {
    my $self = shift;

    my $db = $self->db( 'zonestat-queue' );

    return $db->countDocs - 1;    # We have one design document.
}

1;

=head1 NAME

Zonestat::DB::Queue - database interface class for the gathering queue

=head1 SYNOPSIS

my $q = Zonestat->new->queue;

=head1 DESCRIPTION

=head2 Methods

=over

=item length()

Return the number of domains currently waiting to be gathered or being gathered.

=back
